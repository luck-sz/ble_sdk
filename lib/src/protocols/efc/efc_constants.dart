class EfcConstants {
  /// 主服务 UUID
  static const String serviceUuid = '00112233-4455-6677-8899-aabbccddeeff';

  /// 通知特征值 UUID (Tx - 跑步机 -> App)
  static const String notifyUuid = '01112233-4455-6677-8899-aabbccddeeff';

  /// 写入特征值 UUID (Rx - App -> 跑步机)
  static const String writeUuid = '02112233-4455-6677-8899-aabbccddeeff';

  /// 帧头：App 发往跑步机
  static const int headerTx = 0xA1;

  /// 帧头：跑步机发往 App
  static const int headerRx = 0x1A;

  // --- 命令码 ---
  static const int cmdSpeedControl = 0x01;
  static const int cmdInclineControl = 0x02;
  static const int cmdStatusControl = 0x03;
  static const int cmdReadRecord = 0x04;
  static const int cmdReadDeviceInfo = 0x05;

  // --- 状态控制参数 ---
  static const int statusStart = 0x01;
  static const int statusPause = 0x03;
  static const int statusStop = 0x05;
}
