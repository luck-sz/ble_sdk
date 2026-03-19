import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import '../../core/ble_device.dart';
import '../../core/ble_protocol.dart';
import '../../core/byte_utils.dart';
import '../../models/control_command.dart';
import '../../models/device_info.dart';
import '../../models/machine_status.dart';
import '../../models/machine_type.dart';
import '../../models/supported_ranges.dart';
import '../../models/training_status.dart';
import '../../models/workout_data.dart';
import 'es_constants.dart';
import 'es_control_point.dart';
import 'es_data_parser.dart';
import 'es_handshake_manager.dart';

class EsProtocol implements BleProtocol {
  static const String _tag = 'BleSdk:EsProtocol';

  BleDevice? _device;
  bool _initialized = false;
  bool _handshakeCompleted = false;

  final StreamController<WorkoutData> _workoutDataController =
      StreamController<WorkoutData>.broadcast();
  final StreamController<MachineStatus> _machineStatusController =
      StreamController<MachineStatus>.broadcast();
  final StreamController<TrainingStatus> _trainingStatusController =
      StreamController<TrainingStatus>.broadcast();

  final List<StreamSubscription> _subscriptions = [];
  final List<int> _rxBuffer = [];
  final EsHandshakeManager _handshakeManager = EsHandshakeManager();

  Timer? _syncTimer;
  Completer<bool>? _handshakeCompleter;
  Completer<SupportedRanges>? _rangeCompleter;
  Future<SupportedRanges>? _rangeRequestInFlight;
  SupportedRanges? _supportedRanges;

  int _currentMachineStatus = 0;
  double _currentSpeed = 0.0;
  double _currentIncline = 0.0;

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

    final subscription = device
        .subscribeToCharacteristic(EsConstants.serviceUuid, EsConstants.notifyUuid)
        .listen(_onDataReceived);
    _subscriptions.add(subscription);

    // 在订阅后增加稳定期，防止 iOS 指令冲突导致握手失败
    await Future.delayed(const Duration(milliseconds: 1000));

    _handshakeCompleter = Completer<bool>();
    await _requestHandshake();
    try {
      _handshakeCompleted =
          await _handshakeCompleter!.future.timeout(const Duration(seconds: 3));
    } catch (e) {
      developer.log('[EsProtocol] Handshake TIMEOUT or failed: $e', name: _tag);
      _handshakeCompleted = false;
    }

    _initialized = true;
    _syncTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
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

  Future<void> _requestHandshake() async {
    developer.log('[EsProtocol] Initiating Step 1: Handshake Request...', name: _tag);
    if (_device == null) {
      throw StateError('BLE device is not available for handshake');
    }
    final hsData = _handshakeManager.generatePairingRequest();
    final opCode = hsData[0];
    final payload = hsData.sublist(1);
    final packet = EsControlPoint.buildPacket(opCode, payload);
    await _device!.writeCharacteristic(
      EsConstants.serviceUuid,
      EsConstants.writeUuid,
      packet,
      withResponse: true,
    );
  }

  void _onDataReceived(List<int> data) {
    _rxBuffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (_rxBuffer.length >= 4) {
      final headerIndex = _rxBuffer.indexOf(EsConstants.header);
      if (headerIndex == -1) {
        _rxBuffer.clear();
        return;
      }
      if (headerIndex > 0) {
        _rxBuffer.removeRange(0, headerIndex);
      }
      if (_rxBuffer.length < 4) return;

      final len = _rxBuffer[2];
      final totalPacketLength = len + 4;
      if (_rxBuffer.length < totalPacketLength) return;

      final packet = Uint8List.fromList(_rxBuffer.sublist(0, totalPacketLength));
      _rxBuffer.removeRange(0, totalPacketLength);

      if (EsDataParser.verifyChecksum(packet)) {
        final opCode = packet[1];
        final payload = Uint8List.view(packet.buffer, 3, len);
        _handlePacket(opCode, payload);
      }
    }
  }

  Future<void> _handlePacket(int opCode, Uint8List payload) async {
    switch (opCode) {
      case EsConstants.rspHandshake:
        if (payload.isEmpty) break;
        developer.log('[EsProtocol] Received Handshake Packet: $payload', name: _tag);

        final isFailure = payload.length >= 2 &&
            payload[0] == EsConstants.subOpPairRequest &&
            payload[1] == 0xFF;
        if (isFailure) {
          developer.log(
            '[EsProtocol] Handshake Failure signal (0x01 0xFF) detected.',
            name: _tag,
          );
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(false);
          }
          break;
        }

        if (payload[0] == EsConstants.subOpPassData) {
          final fullHandshakePayload = Uint8List(payload.length + 1);
          fullHandshakePayload[0] = opCode;
          fullHandshakePayload.setRange(1, fullHandshakePayload.length, payload);

          if (_handshakeManager.verifyConsoleResponse(fullHandshakePayload)) {
            developer.log(
              '[EsProtocol] Step 2 Verify SUCCESS. PatternIndex: ${_handshakeManager.lastSentX != null ? _handshakeManager.lastSentX! % 6 : 'N/A'}',
              name: _tag,
            );

            final verificationPacket =
                _handshakeManager.generateValidationReply(fullHandshakePayload);
            if (verificationPacket != null) {
              final resOpCode = verificationPacket[0];
              final resPayload = verificationPacket.sublist(1);
              final pkt = EsControlPoint.buildPacket(resOpCode, resPayload);
              developer.log(
                '[EsProtocol] Sending Step 3 Validation Reply: $resPayload',
                name: _tag,
              );
              await _device?.writeCharacteristic(
                EsConstants.serviceUuid,
                EsConstants.writeUuid,
                pkt,
                withResponse: true,
              );
              try {
                await EsControlPoint.syncStatus(
                  _device!,
                  _currentMachineStatus,
                  _currentSpeed,
                  _currentIncline,
                );
              } catch (e) {
                developer.log(
                  '[EsProtocol] Immediate sync after handshake failed: $e',
                  name: _tag,
                );
              }
            }
          } else {
            developer.log(
              '[EsProtocol] Step 2 Verify FAILED. Data mismatch with expected patterns.',
              name: _tag,
            );
            if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
              _handshakeCompleter!.complete(false);
            }
          }
        }
        break;

      case EsConstants.rspWorkoutData:
        if (!_handshakeCompleted) {
          developer.log(
            '[EsProtocol] Received Step 4 Confirm (0x02 Heartbeat). Handshake SUCCESS!',
            name: _tag,
          );
          _handshakeCompleted = true;
          if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
            _handshakeCompleter!.complete(true);
          }
        }
        final workoutData = EsDataParser.parseWorkoutData(payload);
        _workoutDataController.add(workoutData);
        if (workoutData.instantaneousSpeed != null) {
          _currentSpeed = workoutData.instantaneousSpeed!;
        }
        if (workoutData.inclination != null) {
          _currentIncline = workoutData.inclination!;
        }
        break;

      case EsConstants.rspStatusChange:
        final status = EsDataParser.parseStatusChange(payload);
        _machineStatusController.add(status);
        if (status.statusCode == MachineStatusCode.startedOrResumedByUser) {
          _currentMachineStatus = 2;
        } else if (status.statusCode == MachineStatusCode.stoppedOrPausedByUser &&
            status.controlInfo == 0x02) {
          _currentMachineStatus = 4;
        } else {
          _currentMachineStatus = 0;
        }
        break;

      case EsConstants.rspError:
        _machineStatusController.add(EsDataParser.parseError(payload));
        break;

      case EsConstants.rspSyncInfo:
        final info = EsDataParser.parseSyncInfo(payload);
        if (info.containsKey('speed')) _currentSpeed = info['speed'];
        if (info.containsKey('incline')) _currentIncline = info['incline'];
        _workoutDataController.add(
          WorkoutData(
            machineType: MachineType.treadmill,
            instantaneousSpeed: _currentSpeed,
            inclination: _currentIncline,
          ),
        );
        break;

      case EsConstants.cmdQueryRange:
        _supportedRanges = EsDataParser.parseRangeInfo(payload);
        if (_rangeCompleter != null && !_rangeCompleter!.isCompleted) {
          _rangeCompleter!.complete(_supportedRanges!);
        }
        break;

      default:
        break;
    }
  }

  @override
  Future<void> dispose() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    if (_handshakeCompleter != null && !_handshakeCompleter!.isCompleted) {
      _handshakeCompleter!.complete(false);
    }
    if (_rangeCompleter != null && !_rangeCompleter!.isCompleted) {
      _rangeCompleter!.complete(const SupportedRanges());
    }
    _handshakeCompleter = null;
    _rangeCompleter = null;
    _rangeRequestInFlight = null;

    for (final sub in _subscriptions) {
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
  Future<DeviceInfo> readDeviceInfo() async => const DeviceInfo();

  @override
  Stream<WorkoutData> get workoutDataStream => _workoutDataController.stream;

  @override
  Stream<MachineStatus> get machineStatusStream => _machineStatusController.stream;

  @override
  Stream<TrainingStatus> get trainingStatusStream => _trainingStatusController.stream;

  @override
  Future<ControlResponse> sendCommand(ControlCommand command) async {
    if (_device == null) {
      return ControlResponse(
        requestOpCode: command.opCode,
        resultCode: ControlResultCode.operationFailed,
      );
    }

    if (!_handshakeCompleted && command.opCode != ControlOpCode.requestControl) {
      developer.log(
        '[EsProtocol] Warning: Sending command ${command.opCode} before handshake completed.',
        name: _tag,
      );
    }

    if (command.opCode == ControlOpCode.requestControl && _handshakeCompleted) {
      return ControlResponse(
        requestOpCode: command.opCode,
        resultCode: ControlResultCode.success,
      );
    }

    if (command.opCode == ControlOpCode.setTargetSpeed &&
        command.parameter != null &&
        command.parameter!.length >= 2) {
      _currentSpeed = ByteUtils.readUint16(command.parameter!, 0) / 100.0;
    }
    if (command.opCode == ControlOpCode.setTargetInclination &&
        command.parameter != null &&
        command.parameter!.length >= 2) {
      _currentIncline = ByteUtils.readSint16(command.parameter!, 0) / 10.0;
    }
    if (command.opCode == ControlOpCode.startOrResume) {
      _currentMachineStatus = 2;
    }
    if (command.opCode == ControlOpCode.stopOrPause &&
        command.parameter != null &&
        command.parameter!.isNotEmpty) {
      if (command.parameter![0] == StopPauseParam.stop.code) {
        _currentMachineStatus = 0;
      } else if (command.parameter![0] == StopPauseParam.pause.code) {
        _currentMachineStatus = 4;
      }
    }

    return EsControlPoint.sendCommand(_device!, command);
  }

  @override
  Future<SupportedRanges> readSupportedRanges() async {
    if (!isInitialized || _device == null) return const SupportedRanges();
    if (_supportedRanges != null) return _supportedRanges!;
    if (_rangeRequestInFlight != null) return _rangeRequestInFlight!;

    _rangeRequestInFlight = _querySupportedRanges();
    return _rangeRequestInFlight!;
  }

  Future<SupportedRanges> _querySupportedRanges() async {
    if (_device == null) return const SupportedRanges();
    final activeCompleter = _rangeCompleter = Completer<SupportedRanges>();
    try {
      final packet = EsControlPoint.buildPacket(EsConstants.cmdQueryRange, []);
      await _device!.writeCharacteristic(
        EsConstants.serviceUuid,
        EsConstants.writeUuid,
        packet,
        withResponse: true,
      );
      final ranges = await activeCompleter.future.timeout(const Duration(seconds: 2));
      _supportedRanges ??= ranges;
      return ranges;
    } catch (_) {
      return const SupportedRanges(
        speedRange: SpeedRange(minimum: 0.6, maximum: 16.0, increment: 0.1),
        inclinationRange: InclinationRange(minimum: 0, maximum: 15, increment: 1.0),
      );
    } finally {
      if (identical(_rangeCompleter, activeCompleter)) {
        _rangeCompleter = null;
      }
      _rangeRequestInFlight = null;
    }
  }
}
