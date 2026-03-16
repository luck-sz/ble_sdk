/// EQI 设备错误码。
/// UUID: c4208999-8d92-bee1-4456-2068528eccf6
enum EqiErrorCode {
  /// 子表与控制器之间的通讯故障（0x00）。
  subBoardCommFailure0(0x00, '子表与控制器之间的通讯故障'),

  /// 子表与控制器之间的通讯故障（0x01）。
  subBoardCommFailure1(0x01, '子表与控制器之间的通讯故障'),

  /// 负载变化异常。
  loadChangeAbnormal(0x02, '负载变化异常'),

  /// 控制器未检测到速度信号。
  noSpeedSignal(0x03, '制器未检测到速度信号'),

  /// 升降电机没有学习或学习不成功。
  inclineMotorNotCalibrated(0x04, '升降电机没有学习或学习不成功'),

  /// 马达在运转时电流过大，超过额定电流。
  motorOvercurrent(0x05, '马达在运转时电流过大，超过额定电流'),

  /// 电压过低。
  lowVoltage(0x06, '电压过低'),

  /// 检测不到安全锁的信号。
  safetyKeyNotDetected(0x07, '检测不到安全锁的信号'),

  /// 电子上下表通讯故障。
  boardCommFailure(0x08, '电子上下表通讯故障'),

  /// 升降故障。
  inclineFailure(0x09, '升降故障'),

  /// 工程参数丢失。
  engineeringParamsLost(0x0E, '工程参数丢失'),

  /// 干簧管检测失败。
  reedSwitchFailed(0x21, '干簧管检测失败'),

  /// 拉线器故障。
  cableDeviceFailure(0x22, '拉线器故障'),

  /// 未知故障。
  unknown(0xFF, '未知故障');

  final int code;
  final String description;
  const EqiErrorCode(this.code, this.description);

  static const String uuid = 'c4208999-8d92-bee1-4456-2068528eccf6';

  static EqiErrorCode fromCode(int code) {
    for (final e in values) {
      if (e.code == code) return e;
    }
    return EqiErrorCode.unknown;
  }

  @override
  String toString() =>
      'EqiErrorCode(0x${code.toRadixString(16)}: $description)';
}
