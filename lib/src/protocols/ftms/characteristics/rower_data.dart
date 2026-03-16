import 'dart:typed_data';
import '../../../core/byte_utils.dart';
import '../../../models/workout_data.dart';
import '../../../models/machine_type.dart';

/// 划船机数据特性（0x2AD1）的解析器。
class RowerDataParser {
  RowerDataParser._();

  /// 从原始 BLE 通知字节中解析划船机数据。
  static WorkoutData parse(Uint8List data) {
    if (data.length < 2) {
      return WorkoutData(machineType: MachineType.rower);
    }

    final flags = ByteUtils.readUint16(data, 0);
    int offset = 2;

    // 位 0：More Data（0=划频+划次计数存在）
    double? strokeRate;
    int? strokeCount;
    if (!ByteUtils.isBitSet(flags, 0)) {
      strokeRate = ByteUtils.readUint8(data, offset) / 2.0;
      offset += 1;
      strokeCount = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 1：平均划频（Average Stroke Rate）存在
    double? averageStrokeRate;
    if (ByteUtils.isBitSet(flags, 1)) {
      averageStrokeRate = ByteUtils.readUint8(data, offset) / 2.0;
      offset += 1;
    }

    // 位 2：总距离（Total Distance）存在
    int? totalDistance;
    if (ByteUtils.isBitSet(flags, 2)) {
      totalDistance = ByteUtils.readUint24(data, offset);
      offset += 3;
    }

    // 位 3：瞬时配速（Instantaneous Pace）存在（秒/500米）
    double? instantaneousPace;
    if (ByteUtils.isBitSet(flags, 3)) {
      instantaneousPace = ByteUtils.readUint16(data, offset).toDouble();
      offset += 2;
    }

    // 位 4：平均配速（Average Pace）存在（秒/500米）
    double? averagePace;
    if (ByteUtils.isBitSet(flags, 4)) {
      averagePace = ByteUtils.readUint16(data, offset).toDouble();
      offset += 2;
    }

    // 位 5：瞬时功率（Instantaneous Power）存在
    int? instantaneousPower;
    if (ByteUtils.isBitSet(flags, 5)) {
      instantaneousPower = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 6：平均功率（Average Power）存在
    int? averagePower;
    if (ByteUtils.isBitSet(flags, 6)) {
      averagePower = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 7：阻力等级（Resistance Level）存在
    double? resistanceLevel;
    if (ByteUtils.isBitSet(flags, 7)) {
      resistanceLevel = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 8：消耗热量（Expended Energy）存在
    int? totalEnergy;
    int? energyPerHour;
    int? energyPerMinute;
    if (ByteUtils.isBitSet(flags, 8)) {
      totalEnergy = ByteUtils.readUint16(data, offset);
      offset += 2;
      energyPerHour = ByteUtils.readUint16(data, offset);
      offset += 2;
      energyPerMinute = ByteUtils.readUint8(data, offset);
      offset += 1;
    }

    // 位 9：心率（Heart Rate）存在
    int? heartRate;
    if (ByteUtils.isBitSet(flags, 9)) {
      heartRate = ByteUtils.readUint8(data, offset);
      offset += 1;
    }

    // 位 10：代谢当量（Metabolic Equivalent）存在
    double? metabolicEquivalent;
    if (ByteUtils.isBitSet(flags, 10)) {
      metabolicEquivalent = ByteUtils.readUint8(data, offset) / 10.0;
      offset += 1;
    }

    // 位 11：已运动时间（Elapsed Time）存在
    int? elapsedTime;
    if (ByteUtils.isBitSet(flags, 11)) {
      elapsedTime = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 12：剩余时间（Remaining Time）存在
    int? remainingTime;
    if (ByteUtils.isBitSet(flags, 12)) {
      remainingTime = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    return WorkoutData(
      machineType: MachineType.rower,
      strokeRate: strokeRate,
      strokeCount: strokeCount,
      averageStrokeRate: averageStrokeRate,
      totalDistance: totalDistance,
      instantaneousPace: instantaneousPace,
      averagePace: averagePace,
      instantaneousPower: instantaneousPower,
      averagePower: averagePower,
      resistanceLevel: resistanceLevel,
      totalEnergy: totalEnergy,
      energyPerHour: energyPerHour,
      energyPerMinute: energyPerMinute,
      heartRate: heartRate,
      metabolicEquivalent: metabolicEquivalent,
      elapsedTime: elapsedTime,
      remainingTime: remainingTime,
    );
  }
}
