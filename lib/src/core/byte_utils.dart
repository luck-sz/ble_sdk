import 'dart:typed_data';

/// 字节级数据操作工具类。
///
/// 提供从字节数组中读取不同数据类型的方法，
/// 常用于解析 BLE 特性数据。
class ByteUtils {
  ByteUtils._();

  /// 从 [data] 的 [offset] 位置读取一个无符号 8 位整数。
  static int readUint8(Uint8List data, int offset) {
    if (offset >= data.length) return 0;
    return data[offset];
  }

  /// 从 [data] 的 [offset] 位置读取一个有符号 8 位整数。
  static int readSint8(Uint8List data, int offset) {
    if (offset >= data.length) return 0;
    final value = data[offset];
    return value > 127 ? value - 256 : value;
  }

  /// 从 [data] 的 [offset] 位置读取一个无符号 16 位整数（小端序）。
  static int readUint16(Uint8List data, int offset) {
    if (offset + 1 >= data.length) return 0;
    return data[offset] | (data[offset + 1] << 8);
  }

  /// 从 [data] 的 [offset] 位置读取一个有符号 16 位整数（小端序）。
  static int readSint16(Uint8List data, int offset) {
    if (offset + 1 >= data.length) return 0;
    final value = data[offset] | (data[offset + 1] << 8);
    return value > 32767 ? value - 65536 : value;
  }

  /// 从 [data] 的 [offset] 位置读取一个无符号 24 位整数（小端序）。
  static int readUint24(Uint8List data, int offset) {
    if (offset + 2 >= data.length) return 0;
    return data[offset] | (data[offset + 1] << 8) | (data[offset + 2] << 16);
  }

  /// 从 [data] 的 [offset] 位置读取一个无符号 32 位整数（小端序）。
  static int readUint32(Uint8List data, int offset) {
    if (offset + 3 >= data.length) return 0;
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  /// 将一个无符号 8 位整数写入字节列表。
  static Uint8List writeUint8(int value) {
    return Uint8List.fromList([value & 0xFF]);
  }

  /// 将一个无符号 16 位整数（小端序）写入字节列表。
  static Uint8List writeUint16(int value) {
    return Uint8List.fromList([
      value & 0xFF,
      (value >> 8) & 0xFF,
    ]);
  }

  /// 将一个有符号 16 位整数（小端序）写入字节列表。
  static Uint8List writeSint16(int value) {
    if (value < 0) value += 65536;
    return writeUint16(value);
  }

  /// 将十六进制字符串转换为字节数组。
  static Uint8List hexToBytes(String hex) {
    hex = hex.replaceAll(' ', '').replaceAll('0x', '');
    if (hex.length % 2 != 0) hex = '0$hex';
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// 将字节数组转换为十六进制字符串。
  static String bytesToHex(Uint8List data) {
    return data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }

  /// 检查某个值中指定位是否被置位。
  static bool isBitSet(int value, int bit) {
    return (value >> bit) & 1 == 1;
  }
}
