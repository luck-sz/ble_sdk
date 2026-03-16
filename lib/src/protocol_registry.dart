import 'core/ble_protocol.dart';
import 'models/advertising_data.dart';
import 'protocols/ftms/ftms_protocol.dart';

/// 协议注册中心，负责根据设备广播信息自动匹配并创建对应的协议处理器。
class ProtocolRegistry {
  ProtocolRegistry._();

  /// 支持的所有协议标识符列表。
  static const List<String> supportedProtocols = ['ftms'];

  /// 根据广播数据识别并创建协议实例。
  /// 如果无法识别，则返回 null。
  static BleProtocol? getProtocolForDevice(AdvertisingData ad) {
    // 1. 通过 FTMS 服务 UUID 识别 (0x1826)
    if (ad.machineTypeBitmask != null ||
        (ad.isEqiDevice && ad.machineType != null)) {
      return FtmsProtocol();
    }

    // 2. 如果广播数据中包含 FTMS 标准 Service UUID
    // 注意：这里的逻辑可以根据具体的蓝牙库扫描结果进一步增强
    return null;
  }

  /// 根据协议 ID 手动创建协议实例。
  static BleProtocol? createById(String id) {
    switch (id.toLowerCase()) {
      case 'ftms':
        return FtmsProtocol();
      default:
        return null;
    }
  }
}
