import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ble_sdk/ble_sdk.dart';
import 'package:ble_sdk/src/protocols/efc/efc_constants.dart';
import 'package:ble_sdk/src/protocols/efc/efc_data_parser.dart';

void main() {
  test('FtmsProtocol ID test', () {
    final protocol = FtmsProtocol();
    expect(protocol.protocolId, 'ftms');
  });

  test('EfcDataParser parseMachineStatus preserves status byte', () {
    final bytes = <int>[
      EfcConstants.headerRx,
      0x01, // cmd
      0x07, // len
      0x00,
      0x00,
      0x00,
      0x00,
      25, // speed 2.5
      3, // incline 3
      0x05, // status byte
    ];
    var checksum = 0;
    for (final b in bytes) {
      checksum ^= b;
    }
    bytes.add(checksum);

    final status = EfcDataParser.parseMachineStatus(Uint8List.fromList(bytes));
    expect(status, isNotNull);
    expect(status!.statusCode, MachineStatusCode.rfu);
    expect(status.newTargetSpeed, 2.5);
    expect(status.newTargetIncline, 3.0);
    expect(status.rawParameter, isNotNull);
    expect(status.rawParameter![0], 0x05);
  });
}
