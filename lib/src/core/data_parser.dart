import 'dart:typed_data';

/// 解析 BLE 特性数据的基础类。
///
/// 每个协议的数据特性都应继承此类，以提供
/// 具体的解析逻辑，从而确保不同协议之间
/// 具有一致的接口。
abstract class DataParser<T> {
  /// 将原始 BLE 数据解析为类型化模型。
  T parse(Uint8List data);

  /// 将模型编码回原始 BLE 字节以用于写入。
  Uint8List? encode(T model) => null;
}
