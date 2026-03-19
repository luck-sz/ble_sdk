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
import '../../core/ble_constants.dart';

import 'ftms_constants.dart';
import 'ftms_control_point.dart';
import 'ftms_data_parser.dart';
import 'ftms_machine_feature.dart';
import 'eqi_extension/eqi_extension.dart';

/// FTMS 协议实现类（支持 EQI 私有扩展）。
///
/// 实现了 Fitness Machine Service (0x1826) 标准协议逻辑，
/// 并通过 EqiExtensionManager 整合了 EQI 健身设备的增强功能。
class FtmsProtocol implements BleProtocol {
  static const String _tag = "BleSdk";
  BleDevice? _device;
  bool _initialized = false;

  // 控制点和扩展管理器
  late FtmsControlPoint _controlPoint;
  late EqiExtensionManager _eqiExtension;

  // 暴露扩展管理器供外部使用
  EqiExtensionManager get eqiExtension => _eqiExtension;

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
  String get protocolId => 'ftms';

  @override
  String get protocolName => 'Fitness Machine Service';

  @override
  String get protocolVersion => 'V1.1 (Standard + EQI Extension)';

  @override
  String get serviceUuid => FtmsConstants.serviceUuid;

  @override
  Set<MachineType> get supportedMachineTypes => {
    MachineType.treadmill,
    MachineType.walkingMachine,
    MachineType.crossTrainer,
    MachineType.rower,
    MachineType.indoorBike,
  };

  @override
  bool get isInitialized => _initialized && _device != null;

  @override
  Future<void> initialize(BleDevice device) async {
    developer.log("[$_tag] Initializing FTMS Protocol...", name: _tag);
    _device = device;
    _controlPoint = FtmsControlPoint(device);
    _eqiExtension = EqiExtensionManager(device);

    // 1. 设置扩展管理器订阅
    await _eqiExtension.initialize();
    await Future.delayed(const Duration(milliseconds: 100));

    // 2. 订阅特征值通知 (并行订阅在 iOS 上可能失败，改为串行并加微延迟)
    await _subscribeTo(FtmsConstants.fitnessMachineStatusUuid, (data) {
      _machineStatusController.add(MachineStatus.fromBytes(data));
    });
    await Future.delayed(const Duration(milliseconds: 50));

    await _subscribeTo(FtmsConstants.trainingStatusUuid, (data) {
      _trainingStatusController.add(TrainingStatus.fromBytes(data));
    });
    await Future.delayed(const Duration(milliseconds: 50));

    // 4. 订阅控制点响应 (0x2AD9)
    await _subscribeTo(FtmsConstants.fitnessMachineControlPointUuid, (data) {
      _controlPoint.handleControlPointResponse(data);
    });
    await Future.delayed(const Duration(milliseconds: 100));

    // 5. 根据设备类型订阅运动数据
    // 在 iOS 上，给设备一点响应时间，防止由于前面的订阅还没处理完导致数据通道开启失败
    await Future.delayed(const Duration(milliseconds: 200));

    final subscribedUuids = <String>{};

    for (final machineType in supportedMachineTypes) {
      final uuid = FtmsDataParser.getDataCharacteristicUuid(machineType);
      if (uuid != null) {
        final lowerUuid = uuid.toLowerCase();
        
        // 避免重复订阅同一个 UUID
        if (subscribedUuids.contains(lowerUuid)) continue;
        subscribedUuids.add(lowerUuid);

        await _subscribeTo(uuid, (data) {
          final workoutData = FtmsDataParser.parseWorkoutData(uuid, data, machineType: machineType);
          if (workoutData != null) {
            _workoutDataController.add(workoutData);
          }
        });
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    developer.log("[$_tag] FTMS Protocol initialized", name: _tag);
    _initialized = true;
  }

  /// 辅助方法：订阅特定特征值并管理其订阅实例。
  Future<void> _subscribeTo(String uuid, Function(Uint8List) onData) async {
    try {
      developer.log("[$_tag] Subscribing to characteristic: $uuid", name: _tag);
      final sub = _device!
          .subscribeToCharacteristic(FtmsConstants.serviceUuid, uuid)
          .listen(
            onData,
            onError: (e) {
              developer.log("[$_tag] Stream error for $uuid: $e", name: _tag);
            },
          );
      _subscriptions.add(sub);
    } catch (e) {
      developer.log("[$_tag] Failed to subscribe to $uuid: $e", name: _tag);
    }
  }

  @override
  Future<void> dispose() async {
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    await _eqiExtension.dispose();
    await _workoutDataController.close();
    await _machineStatusController.close();
    await _trainingStatusController.close();

    _initialized = false;
    _device = null;
  }

  @override
  Future<DeviceInfo> readDeviceInfo() async {
    if (!isInitialized) return const DeviceInfo();

    final futures = {
      'manufacturer': _device!.readCharacteristic(
        BleConstants.disServiceUuid,
        BleConstants.manufacturerNameUuid,
      ),
      'model': _device!.readCharacteristic(
        BleConstants.disServiceUuid,
        BleConstants.modelNumberUuid,
      ),
      'fw': _device!.readCharacteristic(
        BleConstants.disServiceUuid,
        BleConstants.firmwareRevisionUuid,
      ),
      'hw': _device!.readCharacteristic(
        BleConstants.disServiceUuid,
        BleConstants.hardwareRevisionUuid,
      ),
    };

    final results = await Future.wait(futures.values);
    final data = futures.keys.toList();

    String parse(Uint8List b) => String.fromCharCodes(b);

    return DeviceInfo(
      manufacturerName: parse(results[data.indexOf('manufacturer')]),
      modelNumber: parse(results[data.indexOf('model')]),
      firmwareRevision: parse(results[data.indexOf('fw')]),
      hardwareRevision: parse(results[data.indexOf('hw')]),
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

    // 并行读取设备支持的所有范围
    final results = await Future.wait([
      _readSafe(FtmsConstants.supportedSpeedRangeUuid),
      _readSafe(FtmsConstants.supportedInclinationRangeUuid),
      _readSafe(FtmsConstants.supportedResistanceRangeUuid),
      _readSafe(FtmsConstants.supportedPowerRangeUuid),
      _readSafe(FtmsConstants.supportedHeartRateRangeUuid),
    ]);

    return SupportedRanges(
      speedRange: results[0] != null ? SpeedRange.fromBytes(results[0]!) : null,
      inclinationRange: results[1] != null
          ? InclinationRange.fromBytes(results[1]!)
          : null,
      resistanceRange: results[2] != null
          ? ResistanceRange.fromBytes(results[2]!)
          : null,
      powerRange: results[3] != null ? PowerRange.fromBytes(results[3]!) : null,
      heartRateRange: results[4] != null
          ? HeartRateRange.fromBytes(results[4]!)
          : null,
    );
  }

  Future<Uint8List?> _readSafe(String uuid) async {
    try {
      return await _device!.readCharacteristic(FtmsConstants.serviceUuid, uuid);
    } catch (_) {
      return null;
    }
  }

  /// 读取设备的功能字。
  Future<FtmsMachineFeature> readFeatures() async {
    final data = await _device!.readCharacteristic(
      FtmsConstants.serviceUuid,
      FtmsConstants.fitnessMachineFeatureUuid,
    );
    return FtmsMachineFeature.fromBytes(data);
  }
}
