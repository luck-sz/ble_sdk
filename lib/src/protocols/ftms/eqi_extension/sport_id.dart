import 'dart:typed_data';

/// EQI 运动 ID 扩展特性。
/// UUID: 62b817cb-47db-c59e-b675-1a66e37a5196
///
/// 当前运动会话的唯一标识符。
/// 由设备 MAC 地址加随机字节生成。
/// 格式：前 6 字节 = 反序 MAC 地址，剩余字节 = 随机数据。
class EqiSportId {
  static const String uuid = '62b817cb-47db-c59e-b675-1a66e37a5196';

  /// 原始运动 ID 字节（最多 12 字节 / Uint96）。
  final Uint8List rawId;

  const EqiSportId({required this.rawId});

  /// 从原始字节解析。
  factory EqiSportId.fromBytes(Uint8List data) {
    return EqiSportId(rawId: data);
  }

  /// 获取运动 ID 的十六进制字符串表示。
  String get hexString =>
      rawId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  @override
  String toString() => 'EqiSportId($hexString)';
}
