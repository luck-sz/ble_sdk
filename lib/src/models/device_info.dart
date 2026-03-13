/// 从设备信息服务（DIS）读取的设备信息。
class DeviceInfo {
  /// 制造商名称（如 'EQI'）
  final String? manufacturerName;

  /// 型号字符串
  final String? modelNumber;

  /// 序列号字符串
  final String? serialNumber;

  /// 硬件版本字符串
  final String? hardwareRevision;

  /// 固件版本字符串
  final String? firmwareRevision;

  /// 软件版本字符串
  final String? softwareRevision;

  /// 系统 ID
  final String? systemId;

  const DeviceInfo({
    this.manufacturerName,
    this.modelNumber,
    this.serialNumber,
    this.hardwareRevision,
    this.firmwareRevision,
    this.softwareRevision,
    this.systemId,
  });

  DeviceInfo copyWith({
    String? manufacturerName,
    String? modelNumber,
    String? serialNumber,
    String? hardwareRevision,
    String? firmwareRevision,
    String? softwareRevision,
    String? systemId,
  }) {
    return DeviceInfo(
      manufacturerName: manufacturerName ?? this.manufacturerName,
      modelNumber: modelNumber ?? this.modelNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      hardwareRevision: hardwareRevision ?? this.hardwareRevision,
      firmwareRevision: firmwareRevision ?? this.firmwareRevision,
      softwareRevision: softwareRevision ?? this.softwareRevision,
      systemId: systemId ?? this.systemId,
    );
  }

  @override
  String toString() {
    return 'DeviceInfo(manufacturer=$manufacturerName, model=$modelNumber, '
        'serial=$serialNumber, hw=$hardwareRevision, fw=$firmwareRevision, '
        'sw=$softwareRevision)';
  }
}
