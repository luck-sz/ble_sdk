import 'dart:typed_data';
import '../../core/byte_utils.dart';

/// 健身设备功能特性（0x2ACC）。
///
/// 包含两个 32 位字段：
/// - 设备功能（Machine Features）：设备能力位掩码
/// - 目标设置功能（Target Setting Features）：支持的控制目标位掩码
class FtmsMachineFeature {
  /// 原始设备功能位掩码（32 位）。
  final int machineFeatures;

  /// 原始目标设置功能位掩码（32 位）。
  final int targetSettingFeatures;

  const FtmsMachineFeature({
    required this.machineFeatures,
    required this.targetSettingFeatures,
  });

  // === 设备功能标志位 ===
  bool get averageSpeedSupported => ByteUtils.isBitSet(machineFeatures, 0);
  bool get cadenceSupported => ByteUtils.isBitSet(machineFeatures, 1);
  bool get totalDistanceSupported => ByteUtils.isBitSet(machineFeatures, 2);
  bool get inclinationSupported => ByteUtils.isBitSet(machineFeatures, 3);
  bool get elevationGainSupported => ByteUtils.isBitSet(machineFeatures, 4);
  bool get paceSupported => ByteUtils.isBitSet(machineFeatures, 5);
  bool get stepCountSupported => ByteUtils.isBitSet(machineFeatures, 6);
  bool get resistanceLevelSupported => ByteUtils.isBitSet(machineFeatures, 7);
  bool get strideCountSupported => ByteUtils.isBitSet(machineFeatures, 8);
  bool get expendedEnergySupported => ByteUtils.isBitSet(machineFeatures, 9);
  bool get heartRateSupported => ByteUtils.isBitSet(machineFeatures, 10);
  bool get metabolicEquivalentSupported => ByteUtils.isBitSet(machineFeatures, 11);
  bool get elapsedTimeSupported => ByteUtils.isBitSet(machineFeatures, 12);
  bool get remainingTimeSupported => ByteUtils.isBitSet(machineFeatures, 13);
  bool get powerMeasurementSupported => ByteUtils.isBitSet(machineFeatures, 14);
  bool get forceOnBeltSupported => ByteUtils.isBitSet(machineFeatures, 15);
  bool get userDataRetentionSupported => ByteUtils.isBitSet(machineFeatures, 16);

  // === 目标设置功能标志位 ===
  bool get speedTargetSupported => ByteUtils.isBitSet(targetSettingFeatures, 0);
  bool get inclinationTargetSupported => ByteUtils.isBitSet(targetSettingFeatures, 1);
  bool get resistanceTargetSupported => ByteUtils.isBitSet(targetSettingFeatures, 2);
  bool get powerTargetSupported => ByteUtils.isBitSet(targetSettingFeatures, 3);
  bool get heartRateTargetSupported => ByteUtils.isBitSet(targetSettingFeatures, 4);
  bool get expendedEnergyConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 5);
  bool get stepNumberConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 6);
  bool get strideNumberConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 7);
  bool get distanceConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 8);
  bool get trainingTimeConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 9);
  bool get twoHrZoneConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 10);
  bool get threeHrZoneConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 11);
  bool get fiveHrZoneConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 12);
  bool get indoorBikeSimulationSupported => ByteUtils.isBitSet(targetSettingFeatures, 13);
  bool get wheelCircumferenceConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 14);
  bool get spinDownControlSupported => ByteUtils.isBitSet(targetSettingFeatures, 15);
  bool get cadenceConfigSupported => ByteUtils.isBitSet(targetSettingFeatures, 16);

  /// 从原始字节解析（共 8 字节：前 4 字节为设备功能，后 4 字节为目标设置功能）。
  factory FtmsMachineFeature.fromBytes(Uint8List data) {
    return FtmsMachineFeature(
      machineFeatures: ByteUtils.readUint32(data, 0),
      targetSettingFeatures: data.length >= 8 ? ByteUtils.readUint32(data, 4) : 0,
    );
  }

  @override
  String toString() {
    final features = <String>[];
    if (averageSpeedSupported) features.add('AvgSpeed');
    if (totalDistanceSupported) features.add('TotalDist');
    if (inclinationSupported) features.add('Incline');
    if (heartRateSupported) features.add('HR');
    if (elapsedTimeSupported) features.add('Time');
    if (powerMeasurementSupported) features.add('Power');
    if (cadenceSupported) features.add('Cadence');
    return 'FtmsMachineFeature(features=[${features.join(', ')}])';
  }
}
