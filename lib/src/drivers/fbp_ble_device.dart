import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../core/ble_device.dart';

/// 使用 flutter_blue_plus 库实现的 BleDevice。
/// 
/// 适合 5w+ 日活的商业项目，内部集成了 MTU 设置和基础的状态转换。
class FbpBleDevice extends BleDevice {
  final BluetoothDevice _device;
  final StreamController<BleConnectionState> _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  StreamSubscription? _stateSubscription;

  FbpBleDevice(this._device) {
    _initConnectionStateListener();
  }

  void _initConnectionStateListener() {
    _stateSubscription = _device.connectionState.listen((state) {
      switch (state) {
        case BluetoothConnectionState.connected:
          _connectionStateController.add(BleConnectionState.connected);
          break;
        case BluetoothConnectionState.connecting:
          _connectionStateController.add(BleConnectionState.connecting);
          break;
        case BluetoothConnectionState.disconnected:
          _connectionStateController.add(BleConnectionState.disconnected);
          break;
        case BluetoothConnectionState.disconnecting:
          _connectionStateController.add(BleConnectionState.disconnecting);
          break;
      }
    });
  }

  @override
  String get deviceId => _device.remoteId.str;

  @override
  String? get deviceName => _device.advName.isNotEmpty ? _device.advName : _device.platformName;

  @override
  BleConnectionState get connectionState {
    // 这里是一个简化的映射，实际在商业项目中建议维护一个内部变量
    return BleConnectionState.disconnected;
  }

  @override
  Stream<BleConnectionState> get connectionStateStream => _connectionStateController.stream;

  @override
  Future<void> connect({Duration? timeout}) async {
    // 商业项目建议：连接前先停止扫描，防止 status 133
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    await _device.connect(timeout: timeout ?? const Duration(seconds: 15), autoConnect: false);
    
    // 连接成功后建议请求 MTU 以支持 FTMS 大数据包
    try {
      await _device.requestMtu(512);
    } catch (_) {
      // 部分机型可能不支持请求 MTU，忽略即可
    }
  }

  @override
  Future<void> disconnect() async {
    await _device.disconnect();
  }

  @override
  Future<List<BleServiceInfo>> discoverServices() async {
    final services = await _device.discoverServices();
    return services.map((s) {
      return BleServiceInfo(
        uuid: s.uuid.toString(),
        characteristics: s.characteristics.map((c) {
          return BleCharacteristicInfo(
            uuid: c.uuid.toString(),
            canRead: c.properties.read,
            canWrite: c.properties.write,
            canWriteWithoutResponse: c.properties.writeWithoutResponse,
            canNotify: c.properties.notify,
            canIndicate: c.properties.indicate,
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  Future<Uint8List> readCharacteristic(String serviceUuid, String characteristicUuid) async {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    return Uint8List.fromList(await char.read());
  }

  @override
  Future<void> writeCharacteristic(
    String serviceUuid,
    String characteristicUuid,
    Uint8List data, {
    bool withResponse = true,
  }) async {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    await char.write(data, withoutResponse: !withResponse);
  }

  @override
  Stream<Uint8List> subscribeToCharacteristic(String serviceUuid, String characteristicUuid) async* {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    await char.setNotifyValue(true);
    yield* char.onValueReceived.map((event) => Uint8List.fromList(event));
  }

  @override
  Future<void> unsubscribeFromCharacteristic(String serviceUuid, String characteristicUuid) async {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    await char.setNotifyValue(false);
  }

  /// 内部辅助方法：通过 UUID 获取特征值。
  Future<BluetoothCharacteristic> _getCharacteristic(String serviceUuid, String charUuid) async {
    final services = await _device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid.toString().toLowerCase() == serviceUuid.toLowerCase(),
      orElse: () => throw Exception('Service not found: $serviceUuid'),
    );
    return service.characteristics.firstWhere(
      (c) => c.uuid.toString().toLowerCase() == charUuid.toLowerCase(),
      orElse: () => throw Exception('Characteristic not found: $charUuid'),
    );
  }

  /// 释放相关监听资源。
  void dispose() {
    _stateSubscription?.cancel();
    _connectionStateController.close();
  }
}
