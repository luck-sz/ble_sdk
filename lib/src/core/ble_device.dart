import 'dart:async';
import 'dart:typed_data';

import 'ble_characteristic.dart';

/// 表示 BLE 设备的连接状态。
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// BLE 设备的抽象表示。
///
/// 这是一个与协议无关的接口，具体实现可以封装
/// 特定平台的 BLE 库（如 flutter_blue_plus、
/// flutter_reactive_ble）。
abstract class BleDevice {
  /// 设备的唯一标识符（地址/ID）。
  String get deviceId;

  /// 设备广播的名称。
  String? get deviceName;

  /// 连接状态变化的数据流。
  Stream<BleConnectionState> get connectionStateStream;

  /// 当前连接状态。
  BleConnectionState get connectionState;

  /// 连接到设备。
  Future<void> connect({Duration? timeout});

  /// 断开与设备的连接。
  Future<void> disconnect();

  /// 发现所有服务和特性。
  Future<List<BleServiceInfo>> discoverServices();

  /// 读取某个特性的值。
  Future<Uint8List> readCharacteristic(String serviceUuid, String characteristicUuid);

  /// 向某个特性写入值。
  Future<void> writeCharacteristic(
    String serviceUuid,
    String characteristicUuid,
    Uint8List data, {
    bool withResponse = true,
  });

  /// 订阅某个特性的通知。
  /// 返回数据更新的数据流。
  Stream<Uint8List> subscribeToCharacteristic(
      String serviceUuid, String characteristicUuid);

  /// 取消订阅通知。
  Future<void> unsubscribeFromCharacteristic(
      String serviceUuid, String characteristicUuid);
}

/// 已发现的 BLE 服务信息。
class BleServiceInfo {
  final String uuid;
  final List<BleCharacteristicInfo> characteristics;

  const BleServiceInfo({
    required this.uuid,
    required this.characteristics,
  });
}

/// 已发现的 BLE 特性信息。
class BleCharacteristicInfo {
  final String uuid;
  final bool canRead;
  final bool canWrite;
  final bool canWriteWithoutResponse;
  final bool canNotify;
  final bool canIndicate;

  const BleCharacteristicInfo({
    required this.uuid,
    this.canRead = false,
    this.canWrite = false,
    this.canWriteWithoutResponse = false,
    this.canNotify = false,
    this.canIndicate = false,
  });
}
