class EsConstants {
  /// 主服务 UUID
  static const String serviceUuid = '0000fff0-0000-1000-8000-00805f9b34fb';

  /// 通知特征值 UUID (Tx - 跑步机 -> App)
  static const String notifyUuid = '0000fff1-0000-1000-8000-00805f9b34fb';

  /// 写入特征值 UUID (Rx - App -> 跑步机)
  static const String writeUuid = '0000fff2-0000-1000-8000-00805f9b34fb';

  /// 帧头
  static const int header = 0xA9; // ES header is 0xA9 for both TX and RX.

  // ==== App -> 跑步机命令 ====
  static const int cmdSetSpeed = 0x01;
  static const int cmdSetIncline = 0x04;
  static const int cmdStatusSync = 0xA0;
  static const int cmdControl = 0xA3;
  static const int cmdHandshake = 0x08;
  static const int cmdQueryRange = 0x0A; // 查询速度和坡度范围
  static const int cmdQueryInfo = 0x1E;
  static const int cmdResetData = 0xF0;

  // ==== ES 握手子操作码 (Sub-OpCodes) ====
  static const int subOpPairRequest = 0x01; // 对码请求/错误通知
  static const int subOpPassData = 0x04;    // 密码数据交换

  // ==== 跑步机 -> App反馈 ====
  static const int rspHandshake = 0x08; // 响应与握手同一个 ID
  static const int rspWorkoutData = 0x02;
  static const int rspStatusChange = 0x09;
  static const int rspError = 0x03;
  static const int rspSyncInfo = 0xF2; // 0xF2 告知当前速度、坡度、公英制

  // ==== 控制相关码 ====
  static const int controlStart = 0x01;
  static const int controlStop = 0x02;
  static const int controlPause = 0x04;
  static const int controlResume = 0x05;
}
