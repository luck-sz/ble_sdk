import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../core/ble_device.dart';

/// BleDevice implementation based on flutter_blue_plus.
class FbpBleDevice extends BleDevice {
  static const String _tag = "BleSdk";
  static const int _connectMaxAttempts = 2;
  static const Duration _connectRetryDelay = Duration(milliseconds: 800);

  final BluetoothDevice _device;
  final StreamController<BleConnectionState> _connectionStateController =
      StreamController<BleConnectionState>.broadcast();
  final Map<String, int> _notifyRefCounts = {};

  StreamSubscription? _stateSubscription;
  List<BluetoothService>? _services;
  BleConnectionState _lastKnownState = BleConnectionState.disconnected;
  bool _disposed = false;

  FbpBleDevice(this._device) {
    _initConnectionStateListener();
  }

  void _initConnectionStateListener() {
    _stateSubscription = _device.connectionState.listen((state) {
      if (_disposed) return;
      developer.log("[$_tag] Connection state changed: $state", name: _tag);
      switch (state) {
        case BluetoothConnectionState.connected:
          _lastKnownState = BleConnectionState.connected;
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(BleConnectionState.connected);
          }
          break;
        case BluetoothConnectionState.disconnected:
          _lastKnownState = BleConnectionState.disconnected;
          _services = null;
          _notifyRefCounts.clear();
          if (!_connectionStateController.isClosed) {
            _connectionStateController.add(BleConnectionState.disconnected);
          }
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
    if (_disposed) {
      throw StateError('FbpBleDevice has been disposed.');
    }
    developer.log("[$_tag] Connecting to device: $deviceId", name: _tag);

    try {
      if (FlutterBluePlus.isScanningNow) {
        developer.log("[$_tag] Stopping scan before connection", name: _tag);
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    for (var attempt = 1; attempt <= _connectMaxAttempts; attempt++) {
      try {
        await _device.connect(
          timeout: timeout ?? const Duration(seconds: 15),
          autoConnect: false,
        );
        developer.log(
          "[$_tag] Connected successfully on attempt $attempt",
          name: _tag,
        );
        break;
      } catch (e) {
        final retryable = _isRetryableConnectError(e);
        developer.log(
          "[$_tag] Connection attempt $attempt failed (retryable=$retryable): $e",
          name: _tag,
          error: e,
        );
        if (!retryable || attempt == _connectMaxAttempts) {
          rethrow;
        }
        await Future.delayed(_connectRetryDelay);
      }
    }

    try {
      developer.log("[$_tag] Requesting MTU 512", name: _tag);
      await _device.requestMtu(512);
    } catch (e) {
      developer.log("[$_tag] Request MTU failed: $e", name: _tag);
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await _device.disconnect();
    } finally {
      _services = null;
      _notifyRefCounts.clear();
    }
  }

  @override
  Future<List<BleServiceInfo>> discoverServices() async {
    _services = await _device.discoverServices();
    return _services!
        .map(
          (s) => BleServiceInfo(
            uuid: s.uuid.toString().toLowerCase(),
            characteristics: s.characteristics
                .map(
                  (c) => BleCharacteristicInfo(
                    uuid: c.uuid.toString().toLowerCase(),
                    canRead: c.properties.read,
                    canWrite: c.properties.write,
                    canWriteWithoutResponse: c.properties.writeWithoutResponse,
                    canNotify: c.properties.notify,
                    canIndicate: c.properties.indicate,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
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
    var useResponse = withResponse;
    if (!char.properties.writeWithoutResponse && char.properties.write) {
      useResponse = true;
    }
    await char.write(data, withoutResponse: !useResponse);
  }

  @override
  Stream<Uint8List> subscribeToCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) {
    return Stream<Uint8List>.multi((controller) async {
      if (_disposed) {
        controller.addError(StateError('FbpBleDevice has been disposed.'));
        await controller.close();
        return;
      }
      final char = await _getCharacteristic(serviceUuid, characteristicUuid);
      final key = _notifyKey(serviceUuid, characteristicUuid);
      final current = _notifyRefCounts[key] ?? 0;
      if (current == 0) {
        await char.setNotifyValue(true);
      }
      _notifyRefCounts[key] = current + 1;
      final sub = char.onValueReceived.listen(
        (event) => controller.add(Uint8List.fromList(event)),
        onError: controller.addError,
      );
      controller.onCancel = () async {
        await sub.cancel();
        final remaining = (_notifyRefCounts[key] ?? 1) - 1;
        if (remaining <= 0) {
          _notifyRefCounts.remove(key);
          try {
            await char.setNotifyValue(false);
          } catch (e) {
            developer.log("[$_tag] Disable notify failed for $key: $e", name: _tag);
          }
        } else {
          _notifyRefCounts[key] = remaining;
        }
      };
    });
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    final char = await _getCharacteristic(serviceUuid, characteristicUuid);
    _notifyRefCounts.remove(_notifyKey(serviceUuid, characteristicUuid));
    await char.setNotifyValue(false);
  }

  Future<BluetoothCharacteristic> _getCharacteristic(
    String serviceUuid,
    String charUuid,
  ) async {
    _services ??= await _device.discoverServices();

    final sGuid = Guid.parse(serviceUuid);
    final cGuid = Guid.parse(charUuid);

    final service = _services!.firstWhere(
      (s) => s.uuid == sGuid,
      orElse: () {
        developer.log(
          '[FbpBleDevice] Service NOT FOUND: $serviceUuid. Available services: ${_services!.map((e) => e.uuid).toList()}',
          name: _tag,
        );
        throw Exception('Service not found: $serviceUuid');
      },
    );

    return service.characteristics.firstWhere(
      (c) => c.uuid == cGuid,
      orElse: () {
        developer.log(
          '[FbpBleDevice] Characteristic NOT FOUND: $charUuid in service $serviceUuid. Available: ${service.characteristics.map((e) => e.uuid).toList()}',
          name: _tag,
        );
        throw Exception('Characteristic not found: $charUuid');
      },
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _services = null;
    _notifyRefCounts.clear();
    await _stateSubscription?.cancel();
    _stateSubscription = null;
    if (!_connectionStateController.isClosed) {
      await _connectionStateController.close();
    }
  }

  bool _isRetryableConnectError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('133') ||
        msg.contains('timeout') ||
        msg.contains('temporar') ||
        msg.contains('busy');
  }

  String _notifyKey(String serviceUuid, String characteristicUuid) =>
      '${serviceUuid.toLowerCase()}|${characteristicUuid.toLowerCase()}';
}
