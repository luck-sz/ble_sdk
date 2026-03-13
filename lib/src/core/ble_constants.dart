/// 所有协议共享的通用 BLE 常量。
class BleConstants {
  BleConstants._();

  // === 标准服务 UUID ===
  static const String ftmsServiceUuid = '00001826-0000-1000-8000-00805f9b34fb';
  static const String disServiceUuid = '0000180a-0000-1000-8000-00805f9b34fb';

  // === DIS 特性 UUID ===
  static const String manufacturerNameUuid = '00002a29-0000-1000-8000-00805f9b34fb';
  static const String modelNumberUuid = '00002a24-0000-1000-8000-00805f9b34fb';
  static const String serialNumberUuid = '00002a25-0000-1000-8000-00805f9b34fb';
  static const String hardwareRevisionUuid = '00002a27-0000-1000-8000-00805f9b34fb';
  static const String firmwareRevisionUuid = '00002a26-0000-1000-8000-00805f9b34fb';
  static const String softwareRevisionUuid = '00002a28-0000-1000-8000-00805f9b34fb';
  static const String systemIdUuid = '00002a23-0000-1000-8000-00805f9b34fb';

  // === EQI 公司 ID ===
  static const int eqiCompanyId = 0x07D5;
}
