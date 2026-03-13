/// EQI 蜂鸣器开关扩展特性。
/// UUID: 4955e40c-73a4-4599-baba-0767f0a9bfcd
///
/// 控制设备蜂鸣器/提示音的开关状态。
class EqiBuzzerSwitch {
  static const String uuid = '4955e40c-73a4-4599-baba-0767f0a9bfcd';

  /// 蜂鸣器是否已启用。
  final bool isEnabled;

  const EqiBuzzerSwitch({required this.isEnabled});

  /// 从原始字节值解析。
  factory EqiBuzzerSwitch.fromByte(int value) {
    return EqiBuzzerSwitch(isEnabled: value == 1);
  }

  /// 编码为字节以用于写入。
  int toByte() => isEnabled ? 1 : 0;

  @override
  String toString() => 'EqiBuzzerSwitch(${isEnabled ? "ON" : "OFF"})';
}
