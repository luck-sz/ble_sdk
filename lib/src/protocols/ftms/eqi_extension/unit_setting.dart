/// EQI 设备的单位制设置值。
enum UnitSystem {
  /// 公制（km、kg 等）
  metric(0x00),

  /// 英制（miles、lbs 等）
  imperial(0x01);

  final int code;
  const UnitSystem(this.code);

  static UnitSystem fromCode(int code) {
    return code == 0x01 ? UnitSystem.imperial : UnitSystem.metric;
  }
}

/// EQI 单位设置扩展特性。
/// UUID: a580d216-7087-5e6c-36b3-77c02f551c85
class EqiUnitSetting {
  static const String uuid = 'a580d216-7087-5e6c-36b3-77c02f551c85';

  /// 当前单位制。
  final UnitSystem unit;

  const EqiUnitSetting({required this.unit});

  /// 从原始字节解析。
  factory EqiUnitSetting.fromByte(int value) {
    return EqiUnitSetting(unit: UnitSystem.fromCode(value));
  }

  /// 编码为字节以用于写入。
  int toByte() => unit.code;

  @override
  String toString() => 'EqiUnitSetting(${unit.name})';
}
