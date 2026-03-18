import 'dart:async';
import 'dart:typed_data';

import 'package:eqi_ble_sdk/src/core/ble_device.dart';
import 'package:eqi_ble_sdk/src/protocols/es/es_constants.dart';
import 'package:eqi_ble_sdk/src/protocols/es/es_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBleDevice extends BleDevice {
  _FakeBleDevice({required this.autoRangeResponse});

  final bool autoRangeResponse;
  final StreamController<Uint8List> _notifyController =
      StreamController<Uint8List>.broadcast();
  final StreamController<BleConnectionState> _stateController =
      StreamController<BleConnectionState>.broadcast();

  bool _handshakeAckSent = false;
  int queryRangeWrites = 0;

  @override
  String get deviceId => 'fake-es';

  @override
  String? get deviceName => 'fake-es-device';

  @override
  BleConnectionState get connectionState => BleConnectionState.connected;

  @override
  Stream<BleConnectionState> get connectionStateStream => _stateController.stream;

  @override
  Future<void> connect({Duration? timeout}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<List<BleServiceInfo>> discoverServices() async => const [];

  @override
  Future<Uint8List> readCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {
    return Uint8List(0);
  }

  @override
  Future<void> writeCharacteristic(
    String serviceUuid,
    String characteristicUuid,
    Uint8List data, {
    bool withResponse = true,
  }) async {
    if (data.length < 2) return;
    final opCode = data[1];
    if (opCode == EsConstants.cmdHandshake && !_handshakeAckSent) {
      _handshakeAckSent = true;
      scheduleMicrotask(() {
        _notifyController.add(_buildPacket(EsConstants.rspWorkoutData, const []));
      });
      return;
    }
    if (opCode == EsConstants.cmdQueryRange) {
      queryRangeWrites++;
      if (autoRangeResponse) {
        scheduleMicrotask(() {
          _notifyController.add(
            _buildPacket(
              EsConstants.cmdQueryRange,
              const [6, 100, 0, 15], // min speed 0.6, max speed 10.0
            ),
          );
        });
      }
    }
  }

  @override
  Stream<Uint8List> subscribeToCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) {
    return _notifyController.stream;
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String serviceUuid,
    String characteristicUuid,
  ) async {}

  Future<void> dispose() async {
    await _notifyController.close();
    await _stateController.close();
  }

  Uint8List _buildPacket(int opCode, List<int> payload) {
    final bytes = <int>[EsConstants.header, opCode, payload.length, ...payload];
    var checksum = 0;
    for (final b in bytes) {
      checksum ^= b;
    }
    bytes.add(checksum);
    return Uint8List.fromList(bytes);
  }
}

void main() {
  test('EsProtocol readSupportedRanges coalesces concurrent requests', () async {
    final fake = _FakeBleDevice(autoRangeResponse: true);
    final protocol = EsProtocol();
    await protocol.initialize(fake);

    final results = await Future.wait([
      protocol.readSupportedRanges(),
      protocol.readSupportedRanges(),
    ]);

    expect(fake.queryRangeWrites, 1);
    expect(results[0].speedRange?.minimum, 0.6);
    expect(results[0].speedRange?.maximum, 10.0);
    expect(results[1].speedRange?.minimum, 0.6);

    await protocol.dispose();
    await fake.dispose();
  });

  test('EsProtocol dispose resolves in-flight range request', () async {
    final fake = _FakeBleDevice(autoRangeResponse: false);
    final protocol = EsProtocol();
    await protocol.initialize(fake);

    final pending = protocol.readSupportedRanges();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await protocol.dispose();
    final result = await pending.timeout(const Duration(seconds: 1));

    expect(fake.queryRangeWrites, 1);
    expect(result.speedRange, isNull);
    expect(result.inclinationRange, isNull);

    await fake.dispose();
  });
}
