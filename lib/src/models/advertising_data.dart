import 'dart:typed_data';
import '../core/byte_utils.dart';
import 'machine_type.dart';

/// 解析自 EQI 设备的 BLE 广播数据。
class AdvertisingData {
  /// 来自完整本地名称（Complete Local Name）的设备名称。
  final String? deviceName;

  /// EQI 公司 ID（0x07D5）。
  final int? companyId;

  /// 来自制造商数据的设备类型。
  final MachineType? machineType;

  /// 来自制造商数据的设备状态。
  final AdvertisingStatus? deviceStatus;

  /// 来自制造商数据的错误码。
  final int? errorCode;

  /// 协议版本（如 0x11 = V1.1）。
  final int? protocolVersion;

  /// 来自制造商数据的 MAC 地址（6 字节）。
  final String? macAddress;

  /// 设备是否可用（来自 FTMS 服务数据标志位）。
  final bool? isAvailable;

  /// 来自 FTMS 服务数据的设备类型位掩码。
  final int? machineTypeBitmask;

  const AdvertisingData({
    this.deviceName,
    this.companyId,
    this.machineType,
    this.deviceStatus,
    this.errorCode,
    this.protocolVersion,
    this.macAddress,
    this.isAvailable,
    this.machineTypeBitmask,
  });

  /// 协议版本的可读字符串（如 "V1.1"）。
  String? get protocolVersionString {
    if (protocolVersion == null) return null;
    final major = (protocolVersion! >> 4) & 0x0F;
    final minor = protocolVersion! & 0x0F;
    return 'V$major.$minor';
  }

  /// 是否为 EQI 设备（通过公司 ID 判断）。
  bool get isEqiDevice => companyId == 0x07D5;

  /// 解析制造商特定数据（AD 类型 0xFF）。
  static AdvertisingData fromManufacturerData(Uint8List data) {
    if (data.length < 6) return const AdvertisingData();

    final companyId = ByteUtils.readUint16(data, 0);
    final deviceType = MachineType.fromCode(data[2]);
    final status = AdvertisingStatus.fromCode(data[3]);
    final errorCode = data[4];
    final protocolVersion = data[5];

    String? macAddress;
    if (data.length >= 12) {
      macAddress = data
          .sublist(6, 12)
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(':');
    }

    return AdvertisingData(
      companyId: companyId,
      machineType: deviceType,
      deviceStatus: status,
      errorCode: errorCode,
      protocolVersion: protocolVersion,
      macAddress: macAddress,
    );
  }

  @override
  String toString() {
    return 'AdvertisingData(name=$deviceName, type=${machineType?.englishName}, '
        'status=${deviceStatus?.name}, version=$protocolVersionString)';
  }
}

/// 广播数据中的设备状态。
enum AdvertisingStatus {
  standby(1, 'Standby'),
  ready(2, 'Ready'),
  running(3, 'Running'),
  pause(4, 'Pause'),
  finish(5, 'Finish'),
  error(6, 'Error');

  final int code;
  final String label;
  const AdvertisingStatus(this.code, this.label);

  static AdvertisingStatus? fromCode(int code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}
