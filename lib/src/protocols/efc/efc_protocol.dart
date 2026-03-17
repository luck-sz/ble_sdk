import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;

import '../../core/ble_device.dart';
import '../../core/ble_protocol.dart';
import '../../models/device_info.dart';
import '../../models/machine_status.dart';
import '../../models/machine_type.dart';
import '../../models/workout_data.dart';
import '../../models/control_command.dart';
import '../../models/supported_ranges.dart';
import '../../models/training_status.dart';

import 'efc_constants.dart';
import 'efc_control_point.dart';
import 'efc_data_parser.dart';

/// EFC 协议实现类（支持 2023 版本）。
class EfcProtocol implements BleProtocol {
  static const String _tag = "BleSdk:EfcProtocol";
  BleDevice? _device;
  bool _initialized = false;

  // 控制点
  late EfcControlPoint _controlPoint;

  // 物理范围缓存
  SupportedRanges? _supportedRanges;

  // 实时状态追踪 (聚合 0x01 和 0x02 的数据)
  double _currentSpeed = 0.0;
  double _currentIncline = 0.0;
  int _currentDistance = 0;
  double _currentEnergy = 0.0;
  int _currentElapsedTime = 0;
  int _currentHeartRate = 0;
  int _currentStepCount = 0;

  // 数据流控制器
  final StreamController<WorkoutData> _workoutDataController =
      StreamController<WorkoutData>.broadcast();
  final StreamController<MachineStatus> _machineStatusController =
      StreamController<MachineStatus>.broadcast();
  final StreamController<TrainingStatus> _trainingStatusController =
      StreamController<TrainingStatus>.broadcast();

  // 订阅列表，用于释放资源
  final List<StreamSubscription> _subscriptions = [];

  @override
  String get protocolId => 'efc';

  @override
  String get protocolName => 'EQI Fitness Control (EFC)';

  @override
  String get protocolVersion => 'V1.0 (20230218)';

  @override
  String get serviceUuid => EfcConstants.serviceUuid;

  @override
  Set<MachineType> get supportedMachineTypes => {
    MachineType.treadmill,
  };

  @override
  bool get isInitialized => _initialized && _device != null;

  @override
  Future<void> initialize(BleDevice device) async {
    developer.log("[$_tag] Initializing EFC Protocol...", name: _tag);
    _device = device;
    _controlPoint = EfcControlPoint(device);

    // 订阅 EFC 的通知特征值 NotifyUuid
    try {
      final sub = _device!
          .subscribeToCharacteristic(
            EfcConstants.serviceUuid,
            EfcConstants.notifyUuid,
          )
          .listen(
            (data) {
              _handleIncomingData(data);
            },
            onError: (e) {
              developer.log("[$_tag] Stream error on NotifyUuid: $e",
                  name: _tag);
            },
          );
      _subscriptions.add(sub);
      developer.log("[$_tag] Subscribed to Notify UUID", name: _tag);
    } catch (e) {
      developer.log("[$_tag] Failed to subscribe to Notify UUID: $e",
          name: _tag);
    }

    _initialized = true;
  }

  /// 处理所有的串口/蓝牙协议通知包
  void _handleIncomingData(Uint8List data) {
    if (data.isEmpty) return;

    // 增加原始日志以便分析协议版本与偏移量
    developer.log("[$_tag] RX Raw: ${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')} (len: ${data.length})", name: _tag);

    if (data[0] != EfcConstants.headerRx) {
      return; // 只接受 0x1A 开头的包
    }

    if (data.length < 5) return;

    int cmd = data[1];

    switch (cmd) {
      case 0x01: // 运动状态/详情 (Current Speed/Incline)
        final status = EfcDataParser.parseMachineStatus(data);
        if (status != null) {
          _machineStatusController.add(status);
          if (status.newTargetSpeed != null) _currentSpeed = status.newTargetSpeed!;
          if (status.newTargetIncline != null) _currentIncline = status.newTargetIncline!;
          
          // 发送完整的聚合数据，防止 UI 闪烁或清零
          _workoutDataController.add(_buildAggregatedData());
        }
        // 解析范围
        final ranges = EfcDataParser.parseSupportedRanges(data);
        if (ranges != null) {
          _supportedRanges = ranges;
        }
        break;
      case 0x02: // 运动数据 (时间、距离、卡路里、步数、心率)
        final workoutData = EfcDataParser.parseWorkoutData(data);
        if (workoutData != null) {
          _currentElapsedTime = workoutData.elapsedTime ?? _currentElapsedTime;
          _currentDistance = workoutData.totalDistance ?? _currentDistance;
          _currentEnergy = workoutData.totalEnergy ?? _currentEnergy;
          _currentStepCount = workoutData.stepCount ?? _currentStepCount;
          _currentHeartRate = workoutData.heartRate ?? _currentHeartRate;

          // 发送聚合数据
          _workoutDataController.add(_buildAggregatedData());
        }
        break;
      case EfcConstants.cmdReadRecord:
      case EfcConstants.cmdReadDeviceInfo:
        // 目前不处理记录和设备信息
        break;
      default:
        // developer.log("[$_tag] Unknown cmd: $cmd", name: _tag);
        break;
    }
  }

  WorkoutData _buildAggregatedData() {
    return WorkoutData(
      machineType: MachineType.treadmill,
      instantaneousSpeed: _currentSpeed,
      inclination: _currentIncline,
      elapsedTime: _currentElapsedTime,
      totalDistance: _currentDistance,
      totalEnergy: _currentEnergy,
      stepCount: _currentStepCount,
      heartRate: _currentHeartRate,
    );
  }

  @override
  Future<void> dispose() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _workoutDataController.close();
    await _machineStatusController.close();
    await _trainingStatusController.close();

    _initialized = false;
    _device = null;
  }

  @override
  Future<DeviceInfo> readDeviceInfo() async {
    // 根据协议（0x05 命令获取），但它是异步且需要交互式请求。
    // 如果没有特别实现，暂时返回空结构。
    if (!isInitialized) return const DeviceInfo();

    developer.log("[$_tag] readDeviceInfo not fully supported in simple mode",
        name: _tag);
    return const DeviceInfo(
      manufacturerName: 'EQI',
      modelNumber: 'EFC-Treadmill',
      softwareRevision: '20230218',
    );
  }

  @override
  Stream<WorkoutData> get workoutDataStream => _workoutDataController.stream;

  @override
  Stream<MachineStatus> get machineStatusStream =>
      _machineStatusController.stream;

  @override
  Stream<TrainingStatus> get trainingStatusStream =>
      _trainingStatusController.stream;

  @override
  Future<ControlResponse> sendCommand(ControlCommand command) async {
    return _controlPoint.sendCommand(command);
  }

  @override
  Future<SupportedRanges> readSupportedRanges() async {
    if (!isInitialized) return const SupportedRanges();

    // 如果已经由 0x01 包同步过了，直接返回
    if (_supportedRanges != null) return _supportedRanges!;

    // 延时等待 1秒，因为设备连接后会自动上传 0x01
    await Future.delayed(const Duration(milliseconds: 1000));
    
    return _supportedRanges ?? const SupportedRanges(
      speedRange: SpeedRange(minimum: 1.0, maximum: 12.0, increment: 0.1),
    );
  }
}
