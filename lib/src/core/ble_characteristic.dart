import 'dart:typed_data';

/// 表示一个 BLE 特性，包含其 UUID 和访问属性。
class BleCharacteristic {
  /// 特性的完整 128 位 UUID 字符串。
  final String uuid;

  /// 特性的可读名称。
  final String name;

  /// 是否支持读取操作。
  final bool canRead;

  /// 是否支持写入操作。
  final bool canWrite;

  /// 是否支持通知（Notify）。
  final bool canNotify;

  /// 是否支持指示（Indicate）。
  final bool canIndicate;

  const BleCharacteristic({
    required this.uuid,
    required this.name,
    this.canRead = false,
    this.canWrite = false,
    this.canNotify = false,
    this.canIndicate = false,
  });

  @override
  String toString() => 'BleCharacteristic($name, uuid=$uuid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleCharacteristic &&
          runtimeType == other.runtimeType &&
          uuid == other.uuid;

  @override
  int get hashCode => uuid.hashCode;
}

/// 处理特性数据通知的回调类型定义。
typedef CharacteristicDataCallback = void Function(
    BleCharacteristic characteristic, Uint8List data);
