import 'package:flutter_test/flutter_test.dart';
import 'package:eqi_ble_sdk/eqi_ble_sdk.dart';

void main() {
  test('FtmsProtocol ID test', () {
    final protocol = FtmsProtocol();
    expect(protocol.protocolId, 'ftms');
  });
}
