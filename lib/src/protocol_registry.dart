import 'core/ble_device.dart';
import 'core/ble_protocol.dart';
import 'models/advertising_data.dart';
import 'protocols/efc/efc_constants.dart';
import 'protocols/efc/efc_protocol.dart';
import 'protocols/es/es_protocol.dart';
import 'protocols/ftms/ftms_protocol.dart';

/// 协议注册中心，负责根据设备通信能力匹配并创建对应的协议处理器。
class ProtocolRegistry {
  ProtocolRegistry._();

  /// 支持的所有协议标识符列表。
  static const List<String> supportedProtocols = ['ftms', 'efc', 'es'];

  /// 【静态启发式】根据广播数据快速预测协议实例。广告数据可能不全且可被伪造，故存在一定不稳定。预测失败返回 null。
  static BleProtocol? getProtocolForDevice(AdvertisingData ad) {
    // 优先级 1: FTMS
    if (ad.machineTypeBitmask != null ||
        (ad.isEqiDevice && ad.machineType != null)) {
      return FtmsProtocol();
    }

    // 优先级 2: EFC / 优先级 3: ES，依靠设备名的启发式分析，实际稳妥需走服务特征
    if (ad.deviceName != null) {
      if (ad.deviceName!.startsWith('EQI-Treadmill') || ad.deviceName!.contains('EFC')) {
        return EfcProtocol();
      }
      if (ad.deviceName!.contains('ES')) {
        return EsProtocol();
      }
    }

    return null;
  }

  /// 【动态稳妥方案】在设备成功连接以后，请求底层设备的完整 Service UUIDs，
  /// 遵循严格的降级匹配优先级：FTMS > EFC > ES
  static Future<BleProtocol?> resolveProtocolAsync(BleDevice device) async {
    try {
      // 获取当前连上的设备的全部真实服务特征
      final services = await device.discoverServices();

      // ============== 优先级 1: 扫描 FTMS (0x1826) 接口 ==============
      bool hasFtms = services.any((s) {
        final uuidStr = s.uuid.toLowerCase();
        return uuidStr.contains('1826') || uuidStr.contains('00001826');
      });
      if (hasFtms) {
        return FtmsProtocol();
      }

      // ============== 优先级 2: 扫描 EFC (00112233) 接口 ==============
      bool hasEfc = services.any(
        (s) => s.uuid.toLowerCase() == EfcConstants.serviceUuid.toLowerCase(),
      );
      if (hasEfc) {
        return EfcProtocol();
      }

      // ============== 优先级 3: 扫描 ES (0000FFF0) 接口 ==============
      bool hasEs = services.any((s) {
        final uuidStr = s.uuid.toLowerCase();
        return uuidStr.contains('fff0');
      });
      if (hasEs) {
        print('[ProtocolRegistry] Detected ES Protocol device.');
        return EsProtocol();
      }

    } catch (e) {
      print('[ProtocolRegistry] Protocol resolution error: $e');
    }

    print('[ProtocolRegistry] No matching protocol found for device features.');
    return null; 
  }

  /// 根据协议 ID 手动创建协议实例。
  static BleProtocol? createById(String id) {
    switch (id.toLowerCase()) {
      case 'ftms':
        return FtmsProtocol();
      case 'efc':
        return EfcProtocol();
      case 'es':
        return EsProtocol();
      default:
        return null;
    }
  }
}
