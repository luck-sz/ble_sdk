import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;

import '../../core/ble_device.dart';
import '../../core/ble_protocol.dart';
import '../../core/byte_utils.dart';
import '../../models/device_info.dart';
import '../../models/machine_status.dart';
import '../../models/machine_type.dart';
import '../../models/workout_data.dart';
import '../../models/control_command.dart';
import '../../models/supported_ranges.dart';
import '../../models/training_status.dart';

import 'es_constants.dart';
import 'es_data_parser.dart';
import 'es_control_point.dart';
import 'es_handshake_manager.dart';

/// ES (EQI Standard) 协议完整实现。
class EsProtocol implements BleProtocol {
  static const String _tag = 'BleSdk:EsProtocol';
  BleDevice? _device;
  bool _initialized = false;
  bool _handshakeCompleted = false;

  final StreamController<WorkoutData> _workoutDataController = StreamController<WorkoutData>.broadcast();
  final StreamController<MachineStatus> _machineStatusController = StreamController<MachineStatus>.broadcast();
  final StreamController<TrainingStatus> _trainingStatusController = StreamController<TrainingStatus>.broadcast();

  final List<StreamSubscription> _subscriptions = [];
  Timer? _syncTimer;
  
  // 假定我们需要实时维护这些数据发送给设备进行面板同步 (0xA0 命令)
  int _currentMachineStatus = 0; // 0 standby default
  double _currentSpeed = 0.0;
  double _currentIncline = 0.0;

  final EsHandshakeManager _handshakeManager = EsHandshakeManager();
  Completer<bool>? _handshakeCompleter;

  // 接收数据缓冲
  final List<int> _rxBuffer = [];

  // 物理限制范围缓存
  SupportedRanges? _supportedRanges;
  Completer<SupportedRanges>? _rangeCompleter;

  @override
  String get protocolId => 'es';

  @override
  String get protocolName => 'EQI Standard (ES)';

  @override
  String get protocolVersion => 'V1.0 (20201117)';

  @override
  String get serviceUuid => EsConstants.serviceUuid;

  @override
  Set<MachineType> get supportedMachineTypes => {
    MachineType.treadmill,
    MachineType.crossTrainer,
    MachineType.indoorBike,
    MachineType.rower,
  };

  @override
  bool get isInitialized => _initialized && _device != null && _handshakeCompleted;

  @override
  Future<void> initialize(BleDevice device) async {
    _device = device;
    _rxBuffer.clear();

    // 订阅 Notify 特征值
    final subscription = device.subscribeToCharacteristic(
      EsConstants.serviceUuid,
      EsConstants.notifyUuid,
    ).listen(_onDataReceived);

    _subscriptions.add(subscription);

    // 延时 500ms 确保系统的 CCCD (Notify) 设置彻底完成并生效
    await Future.delayed(const Duration(milliseconds: 500));

    // 触发握手流程
    _handshakeCompleter = Completer<bool>();
    await _requestHandshake(); // 显式等待握手包发送成功

    // 等待握手完成逻辑...
    try {
      // 降低超时等待时间到 3秒，提升重试效率
      _handshakeCompleted = await _handshakeCompleter!.future.timeout(const Duration(seconds: 3));
    } catch (e) {
      developer.log('[EsProtocol] Handshake TIMEOUT or failed: $e', name: _tag);
      _handshakeCompleted = false;
    }

    _initialized = true;

    // 开启同步引擎 (0xA0)
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_handshakeCompleted && isInitialized && _device != null) {
        try {
          await EsControlPoint.syncStatus(
            _device!,
            _currentMachineStatus,
            _currentSpeed,
            _currentIncline,
          );
        } catch (e) {
          developer.log('[EsProtocol] Periodic sync failed: $e', name: _tag);
        }
      }
    });
  }

  /// 步骤 1：APP 发起对码请求 (A9 08 02 01 X CS)
  Future<void> _requestHandshake() async {
    developer.log('[EsProtocol] Initiating Step 1: Handshake Request...', name: _tag);
    if (_device == null) {
      throw StateError('BLE device is not available for handshake');
    }
    Uint8List hsData = _handshakeManager.generatePairingRequest();
    int opCode = hsData[0];
    List<int> payload = hsData.sublist(1);
    
    Uint8List packet = EsControlPoint.buildPacket(opCode, payload);
    await _device!.writeCharacteristic(
      EsConstants.serviceUuid,
      EsConstants.writeUuid,
      packet,
      withResponse: true, // 握手包建议用 withResponse 确保抵达
    );
  }

  void _onDataReceived(List<int> data) {
    _rxBuffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    // 包格式：Header(1) + OpCode(1) + Len(1) + Payload(Len) + CS(1)
    // 最小包 = 4 bytes (Length == 0)
    while (_rxBuffer.length >= 4) {
      // 找帧头
      int headerIndex = _rxBuffer.indexOf(EsConstants.header);
      if (headerIndex == -1) {
        _rxBuffer.clear();
        return;
      }

      if (headerIndex > 0) {
        _rxBuffer.removeRange(0, headerIndex);
      }

      if (_rxBuffer.length < 4) return;

      int len = _rxBuffer[2];
      int totalPacketLength = len + 4; // Header(1) + ID(1) + Len(1) + Payload(len) + CS(1)

      if (_rxBuffer.length < totalPacketLength) {
        // 数据不够，等待下次接收
        return;
      }

      // 提取完整的包
      Uint8List packet = Uint8List.fromList(_rxBuffer.sublist(0, totalPacketLength));
      
      // 出队
      _rxBuffer.removeRange(0, totalPacketLength);

      // 校验
      if (EsDataParser.verifyChecksum(packet)) {
        int opCode = packet[1];
        Uint8List payload = Uint8List.view(packet.buffer, 3, len);
        _handlePacket(opCode, payload);
      }
    }
  }

  void _handlePacket(int opCode, Uint8List payload) async {
    switch (opCode) {
      case EsConstants.rspHandshake: // 0x08
        // 对码响应或错误
        if (payload.isEmpty) break;
        
        developer.log('[EsProtocol] Received Handshake Packet: $payload', name: _tag);

        // 处理错误信号: 08 01 FF (Payload: 01 FF)
        bool isFailure = (payload.length >= 2 && payload[0] == EsConstants.subOpPairRequest && payload[1] == 0xFF);
        if (isFailure) {
           developer.log('[EsProtocol] Handshake Failure signal (0x01 0xFF) detected.', name: _tag);
           if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
             _handshakeCompleter!.complete(false);
           }
           break;
        }

        // 处理数据校验: 08 04 C D E F (Payload: 04 C D E F)
        if (payload[0] == EsConstants.subOpPassData) {
            // 回包数据拼装回握手管理器需要的完整格式：[OpCode, Payload...]
            final fullHandshakePayload = Uint8List(payload.length + 1);
            fullHandshakePayload[0] = opCode;
            fullHandshakePayload.setRange(1, fullHandshakePayload.length, payload);

            if (_handshakeManager.verifyConsoleResponse(fullHandshakePayload)) {
               developer.log('[EsProtocol] Step 2 Verify SUCCESS. PatternIndex: ${_handshakeManager.lastSentX != null ? _handshakeManager.lastSentX! % 6 : 'N/A'}', name: _tag);
               
               Uint8List? verificationPacket = _handshakeManager.generateValidationReply(fullHandshakePayload);
               if (verificationPacket != null) {
                  int resOpCode = verificationPacket[0];
                  List<int> resPayload = verificationPacket.sublist(1);
                  Uint8List pkt = EsControlPoint.buildPacket(resOpCode, resPayload);
                  
                  developer.log('[EsProtocol] Sending Step 3 Validation Reply: $resPayload', name: _tag);
                  await _device?.writeCharacteristic(EsConstants.serviceUuid, EsConstants.writeUuid, pkt, withResponse: true);
                  
                  // 开始发送心跳包 (0xA0) 以告知正在对接
                  try {
                    await EsControlPoint.syncStatus(
                      _device!,
                      _currentMachineStatus,
                      _currentSpeed,
                      _currentIncline,
                    );
                  } catch (e) {
                    developer.log('[EsProtocol] Immediate sync after handshake failed: $e', name: _tag);
                  }
               }
            } else {
               developer.log('[EsProtocol] Step 2 Verify FAILED. Data mismatch with expected patterns.', name: _tag);
               if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
                 _handshakeCompleter!.complete(false);
               }
            }
        }
        break;

      case EsConstants.rspWorkoutData: // 0x02
        if (!_handshakeCompleted) {
          developer.log('[EsProtocol] Received Step 4 Confirm (0x02 Heartbeat). Handshake SUCCESS!', name: _tag);
          _handshakeCompleted = true;
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
             _handshakeCompleter!.complete(true);
          }
        }
        WorkoutData workoutData = EsDataParser.parseWorkoutData(payload);
        _workoutDataController.add(workoutData);

        // 同步当前的参数，这样心跳能发正确的数据
        if (workoutData.instantaneousSpeed != null) {
           _currentSpeed = workoutData.instantaneousSpeed!;
        }
        if (workoutData.inclination != null) {
           _currentIncline = workoutData.inclination!;
        }
        break;

      case EsConstants.rspStatusChange: // 0x09
        MachineStatus status = EsDataParser.parseStatusChange(payload);
        _machineStatusController.add(status);
        if (status.statusCode == MachineStatusCode.startedOrResumedByUser) {
          _currentMachineStatus = 2; // Running
        } else if (status.statusCode == MachineStatusCode.stoppedOrPausedByUser && status.controlInfo == 0x02) {
          _currentMachineStatus = 4; // Paused
        } else {
          _currentMachineStatus = 0; // Standby/Stopped
        }
        break;

      case EsConstants.rspError: // 0x03
        MachineStatus errorStatus = EsDataParser.parseError(payload);
        _machineStatusController.add(errorStatus);
        break;

      case EsConstants.rspSyncInfo: // 0xF2
        final info = EsDataParser.parseSyncInfo(payload);
        if (info.containsKey('speed')) {
          _currentSpeed = info['speed'];
        }
        if (info.containsKey('incline')) {
          _currentIncline = info['incline'];
        }
        _workoutDataController.add(WorkoutData(
          machineType: MachineType.treadmill,
          instantaneousSpeed: _currentSpeed,
          inclination: _currentIncline,
        ));
        break;

      case EsConstants.cmdQueryRange: // 0x0A 响应速度范围
        _supportedRanges = EsDataParser.parseRangeInfo(payload);
        if (_rangeCompleter != null && !_rangeCompleter!.isCompleted) {
          _rangeCompleter!.complete(_supportedRanges!);
        }
        break;
      
      default:
        // 未知 OpCode
        break;
    }
  }

  @override
  Future<void> dispose() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _workoutDataController.close();
    await _machineStatusController.close();
    await _trainingStatusController.close();

    _initialized = false;
    _handshakeCompleted = false;
    _device = null;
  }

  @override
  Future<DeviceInfo> readDeviceInfo() async => const DeviceInfo(); // ES 无标准的通用 DeviceInfo 命令，留空或可定制

  @override
  Stream<WorkoutData> get workoutDataStream => _workoutDataController.stream;

  @override
  Stream<MachineStatus> get machineStatusStream => _machineStatusController.stream;

  @override
  Stream<TrainingStatus> get trainingStatusStream => _trainingStatusController.stream;

  @override
  Future<ControlResponse> sendCommand(ControlCommand command) async {
    if (_device == null) {
      return ControlResponse(requestOpCode: command.opCode, resultCode: ControlResultCode.operationFailed);
    }
    
    // 如果尚未握手成功且不是请求控制命令，记录警告但尝试发送
    if (!_handshakeCompleted && command.opCode != ControlOpCode.requestControl) {
      developer.log('[EsProtocol] Warning: Sending command ${command.opCode} before handshake completed.', name: _tag);
    }
    
    // 如果是 requestControl 指令，且握手已经成功，我们直接模拟返回成功
    if (command.opCode == ControlOpCode.requestControl && _handshakeCompleted) {
       return ControlResponse(requestOpCode: command.opCode, resultCode: ControlResultCode.success);
    }
    
    // 拦截设置速度/坡度等命令并将当前心跳用到的值马上改过来，加速反应
    if (command.opCode == ControlOpCode.setTargetSpeed && command.parameter != null && command.parameter!.length >= 2) {
      _currentSpeed = ByteUtils.readUint16(command.parameter!, 0) / 100.0;
    }
    if (command.opCode == ControlOpCode.setTargetInclination && command.parameter != null && command.parameter!.length >= 2) {
      _currentIncline = ByteUtils.readSint16(command.parameter!, 0) / 10.0;
    }
    if (command.opCode == ControlOpCode.startOrResume) _currentMachineStatus = 2; // running
    if (command.opCode == ControlOpCode.stopOrPause) {
      if (command.parameter != null && command.parameter!.isNotEmpty) {
        if (command.parameter![0] == StopPauseParam.stop.code) {
          _currentMachineStatus = 0; // stopped
        } else if (command.parameter![0] == StopPauseParam.pause.code) {
          _currentMachineStatus = 4; // paused
        }
      }
    }

    return await EsControlPoint.sendCommand(_device!, command);
  }

  @override
  Future<SupportedRanges> readSupportedRanges() async {
    if (!isInitialized || _device == null) return const SupportedRanges();
    
    if (_supportedRanges != null) return _supportedRanges!;

    _rangeCompleter = Completer<SupportedRanges>();
    
    // 发送 0x0A 请求
    Uint8List packet = EsControlPoint.buildPacket(EsConstants.cmdQueryRange, []);
    await _device!.writeCharacteristic(
      EsConstants.serviceUuid,
      EsConstants.writeUuid,
      packet,
      withResponse: true,
    );

    try {
      return await _rangeCompleter!.future.timeout(const Duration(seconds: 2));
    } catch (_) {
      // 超时返回默认值（或者空的，由 UI 控制）
      return const SupportedRanges(
        speedRange: SpeedRange(minimum: 0.6, maximum: 16.0, increment: 0.1),
        inclinationRange: InclinationRange(minimum: 0, maximum: 15, increment: 1.0),
      );
    }
  }
}
