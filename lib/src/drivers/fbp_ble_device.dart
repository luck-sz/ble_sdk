import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:developer' as developer;
import '../core/ble_device.dart';

/// 使用 flutter_blue_plus 库实现的 BleDevice。
///
/// 适合 5w+ 日活的商业项目，内部集成了 MTU 设置和基础的状态转换。
class FbpBleDevice extends BleDevice {
  static const String _tag = "BleSdk";
  final BluetoothDevice _device;
  final StreamController<BleConnectionState> _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  StreamSubscription? _stateSubscription;
  BleConnectionState _lastKnownState = BleConnectionState.disconnected;

  FbpBleDevice(this._device) {
    _initConnectionStateListener();
  }

  void _initConnectionStateListener() {
    _stateSubscription = _device.connectionState.listen((state) {
      developer.log("[$_tag] Connection state changed: $state", name: _tag);
      switch (state) {
        case BluetoothConnectionState.connected:
          _lastKnownState = BleConnectionState.connected;
          _connectionStateController.add(BleConnectionState.connected);
          break;
        case BluetoothConnectionState.disconnected:
          _lastKnownState = BleConnectionState.disconnected;
          _connectionStateController.add(BleConnectionState.disconnected);
          break;
        default:
          break;
      }
    });
  }

  @override
  String get deviceId => _device.remoteId.str;

  @override
  String? get deviceName =>
      _device.advName.isNotEmpty ? _device.advName : _device.platformName;

  @override
  BleConnectionState get connectionState => _lastKnownState;

  @override
  Stream<BleConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  @override
  Future<void> connect({Duration? timeout}) async {
    developer.log("[$_tag] Connecting to device: $deviceId", name: _tag);
    // 商业项目建议：连接前先停止扫描，防止 status 133
    try {
      if (FlutterBluePlus.isScanningNow) {
        developer.log("[$_tag] Stopping scan before connection", name: _tag);
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    try {
      await _device.connect(
        timeout: timeout ?? const Duration(seconds: 15),
        autoConnect: false,
      );
      developer.log("[$_tag] Connected successfully", name: _tag);
    } catch (e) {
      developer.log("[$_tag] Connection failed: $e", name: _tag, error: e);
      rethrow;
    }

    // 连接成功后建议请求 MTU 以支持 FTMS 大数据包
    try {
      developer.log("[$_tag] Requesting MTU 512", name: _tag);
      await _device.requestMtu(512);
    } catch (e) {
      developer.log("[$_tag] Request MTU failed: $e", name: _tag);
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
  Future<Uint8List> readCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
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
  Stream<Uint8List> subscribeToCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async* {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    await char.setNotifyValue(true);
    yield* char.onValueReceived.map((event) => Uint8List.fromList(event));
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    await char.setNotifyValue(false);
  }

  /// 内部辅助方法：通过 UUID 获取特征值。
  Future<BluetoothCharacteristic> _getCharacteristic(
    String serviceUuid,
    String charUuid,
  ) async {
    List<BluetoothService> services = await _device.discoverServices();

    final service = services.firstWhere(
      (s) => s.uuid == Guid.parse(serviceUuid),
      orElse: () => throw Exception('Service not found: $serviceUuid'),
    );
    return service.characteristics.firstWhere(
      (c) => c.uuid == Guid.parse(charUuid),
      orElse: () => throw Exception('Characteristic not found: $charUuid'),
    );
  }

  /// 释放相关监听资源。
  void dispose() {
    _stateSubscription?.cancel();
    _connectionStateController.close();
  }
}
