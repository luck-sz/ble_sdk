import 'dart:async';

import 'ble_device.dart';
import '../models/device_info.dart';
import '../models/machine_type.dart';
import '../models/workout_data.dart';
import '../models/control_command.dart';
import '../models/machine_status.dart';
import '../models/supported_ranges.dart';
import '../models/training_status.dart';

/// 基础协议接口。
///
/// 所有 BLE 协议（FTMS、EFC、ES 等）都必须实现此接口。
/// 这是核心扩展点——要添加新协议，只需创建一个
/// 实现了 [BleProtocol] 的新类。
abstract class BleProtocol {
  /// 协议标识符（如 'ftms'、'efc'、'es'）。
  String get protocolId;

  /// 协议的可读名称。
  String get protocolName;

  /// 协议版本字符串。
  String get protocolVersion;

  /// 该协议使用的服务 UUID。
  String get serviceUuid;

  /// 该协议支持的设备类型集合。
  Set<MachineType> get supportedMachineTypes;

  /// 使用已连接的 BLE 设备初始化协议。
  /// 此方法应执行服务发现并设置通知订阅。
  Future<void> initialize(BleDevice device);

  /// 释放资源并取消通知订阅。
  Future<void> dispose();

  /// 从 DIS 服务读取设备信息。
  Future<DeviceInfo> readDeviceInfo();

  /// 实时运动数据流。
  Stream<WorkoutData> get workoutDataStream;

  /// 设备状态变化的数据流。
  Stream<MachineStatus> get machineStatusStream;

  /// 训练状态变化的数据流。
  Stream<TrainingStatus> get trainingStatusStream;

  /// 向设备发送控制命令。
  Future<ControlResponse> sendCommand(ControlCommand command);

  /// 读取设备支持的参数范围。
  Future<SupportedRanges> readSupportedRanges();

  /// 协议当前是否已连接并完成初始化。
  bool get isInitialized;
}
