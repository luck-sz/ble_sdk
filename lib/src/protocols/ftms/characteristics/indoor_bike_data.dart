import 'dart:typed_data';
import '../../../core/byte_utils.dart';
import '../../../models/workout_data.dart';
import '../../../models/machine_type.dart';

/// 室内单车数据特性（0x2AD2）的解析器。
class IndoorBikeDataParser {
  IndoorBikeDataParser._();

  /// 从原始 BLE 通知字节中解析室内单车数据。
  static WorkoutData parse(Uint8List data, {MachineType? machineType}) {
    if (data.length < 2) {
      return WorkoutData(machineType: machineType ?? MachineType.indoorBike);
    }

    final flags = ByteUtils.readUint16(data, 0);
    int offset = 2;

    // 位 0：More Data（0=瞬时速度存在）
    double? instantaneousSpeed;
    if (!ByteUtils.isBitSet(flags, 0)) {
      if (offset + 2 <= data.length) {
        instantaneousSpeed = ByteUtils.readUint16(data, offset) / 100.0;
        offset += 2;
      }
    }

    // 位 1：平均速度（Average Speed）存在
    double? averageSpeed;
    if (ByteUtils.isBitSet(flags, 1)) {
      if (offset + 2 <= data.length) {
        averageSpeed = ByteUtils.readUint16(data, offset) / 100.0;
        offset += 2;
      }
    }

    // 位 2：瞬时踏频（Instantaneous Cadence）存在
    double? instantaneousCadence;
    if (ByteUtils.isBitSet(flags, 2)) {
      if (offset + 2 <= data.length) {
        instantaneousCadence = ByteUtils.readUint16(data, offset) / 2.0;
        offset += 2;
      }
    }

    // 位 3：平均踏频（Average Cadence）存在
    double? averageCadence;
    if (ByteUtils.isBitSet(flags, 3)) {
      if (offset + 2 <= data.length) {
        averageCadence = ByteUtils.readUint16(data, offset) / 2.0;
        offset += 2;
      }
    }

    // 位 4：总距离（Total Distance）存在
    int? totalDistance;
    if (ByteUtils.isBitSet(flags, 4)) {
      if (offset + 3 <= data.length) {
        totalDistance = ByteUtils.readUint24(data, offset);
        offset += 3;
      } else if (offset + 2 <= data.length) {
        totalDistance = ByteUtils.readUint16(data, offset);
        offset += 2;
      }
    }

    // 位 5：阻力等级（Resistance Level）存在
    double? resistanceLevel;
    if (ByteUtils.isBitSet(flags, 5)) {
      if (offset + 2 <= data.length) {
        resistanceLevel = ByteUtils.readSint16(data, offset) / 10.0;
        offset += 2;
      }
    }

    // 位 6：瞬时功率（Instantaneous Power）存在
    int? instantaneousPower;
    if (ByteUtils.isBitSet(flags, 6)) {
      if (offset + 2 <= data.length) {
        instantaneousPower = ByteUtils.readSint16(data, offset);
        offset += 2;
      }
    }

    // 位 7：平均功率（Average Power）存在
    int? averagePower;
    if (ByteUtils.isBitSet(flags, 7)) {
      if (offset + 2 <= data.length) {
        averagePower = ByteUtils.readSint16(data, offset);
        offset += 2;
      }
    }

    // 位 8：消耗热量（Expended Energy）存在
    double? totalEnergy;
    int? energyPerHour;
    int? energyPerMinute;
    if (ByteUtils.isBitSet(flags, 8)) {
      if (offset + 2 <= data.length) {
        totalEnergy = ByteUtils.readUint16(data, offset).toDouble();
        offset += 2;
      }
      if (offset + 2 <= data.length) {
        energyPerHour = ByteUtils.readUint16(data, offset);
        offset += 2;
      }
      if (offset + 1 <= data.length) {
        energyPerMinute = ByteUtils.readUint8(data, offset);
        offset += 1;
      }
    }

    // 位 9：心率（Heart Rate）存在
    int? heartRate;
    if (ByteUtils.isBitSet(flags, 9)) {
      if (offset + 1 <= data.length) {
        heartRate = ByteUtils.readUint8(data, offset);
        offset += 1;
      }
    }

    // 位 10：代谢当量（Metabolic Equivalent）存在
    double? metabolicEquivalent;
    if (ByteUtils.isBitSet(flags, 10)) {
      if (offset + 1 <= data.length) {
        metabolicEquivalent = ByteUtils.readUint8(data, offset) / 10.0;
        offset += 1;
      }
    }

    // 位 11：已运动时间（Elapsed Time）存在
    int? elapsedTime;
    if (ByteUtils.isBitSet(flags, 11)) {
      if (offset + 2 <= data.length) {
        elapsedTime = ByteUtils.readUint16(data, offset);
        offset += 2;
      }
    }

    // 位 12：剩余时间（Remaining Time）存在
    int? remainingTime;
    if (ByteUtils.isBitSet(flags, 12)) {
      if (offset + 2 <= data.length) {
        remainingTime = ByteUtils.readUint16(data, offset);
        offset += 2;
      }
    }

    return WorkoutData(
      machineType: machineType ?? MachineType.indoorBike,
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
