import 'dart:typed_data';
import '../../../core/byte_utils.dart';
import '../../../models/workout_data.dart';
import '../../../models/machine_type.dart';

/// 室内单车数据特性（0x2AD2）的解析器。
class IndoorBikeDataParser {
  IndoorBikeDataParser._();

  /// 从原始 BLE 通知字节中解析室内单车数据。
  static WorkoutData parse(Uint8List data) {
    if (data.length < 2) {
      return WorkoutData(machineType: MachineType.indoorBike);
    }

    final flags = ByteUtils.readUint16(data, 0);
    int offset = 2;

    // 位 0：More Data（0=瞬时速度存在）
    double? instantaneousSpeed;
    if (!ByteUtils.isBitSet(flags, 0)) {
      instantaneousSpeed = ByteUtils.readUint16(data, offset) / 100.0;
      offset += 2;
    }

    // 位 1：平均速度（Average Speed）存在
    double? averageSpeed;
    if (ByteUtils.isBitSet(flags, 1)) {
      averageSpeed = ByteUtils.readUint16(data, offset) / 100.0;
      offset += 2;
    }

    // 位 2：瞬时踏频（Instantaneous Cadence）存在
    double? instantaneousCadence;
    if (ByteUtils.isBitSet(flags, 2)) {
      instantaneousCadence = ByteUtils.readUint16(data, offset) / 2.0;
      offset += 2;
    }

    // 位 3：平均踏频（Average Cadence）存在
    double? averageCadence;
    if (ByteUtils.isBitSet(flags, 3)) {
      averageCadence = ByteUtils.readUint16(data, offset) / 2.0;
      offset += 2;
    }

    // 位 4：总距离（Total Distance）存在
    int? totalDistance;
    if (ByteUtils.isBitSet(flags, 4)) {
      totalDistance = ByteUtils.readUint24(data, offset);
      offset += 3;
    }

    // 位 5：阻力等级（Resistance Level）存在
    double? resistanceLevel;
    if (ByteUtils.isBitSet(flags, 5)) {
      resistanceLevel = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 6：瞬时功率（Instantaneous Power）存在
    int? instantaneousPower;
    if (ByteUtils.isBitSet(flags, 6)) {
      instantaneousPower = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 7：平均功率（Average Power）存在
    int? averagePower;
    if (ByteUtils.isBitSet(flags, 7)) {
      averagePower = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 8：消耗热量（Expended Energy）存在
    double? totalEnergy;
    int? energyPerHour;
    int? energyPerMinute;
    if (ByteUtils.isBitSet(flags, 8)) {
      totalEnergy = ByteUtils.readUint16(data, offset).toDouble();
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
      machineType: MachineType.indoorBike,
      instantaneousSpeed: instantaneousSpeed,
      averageSpeed: averageSpeed,
      instantaneousCadence: instantaneousCadence,
      averageCadence: averageCadence,
      totalDistance: totalDistance,
      resistanceLevel: resistanceLevel,
      instantaneousPower: instantaneousPower,
      averagePower: averagePower,
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
