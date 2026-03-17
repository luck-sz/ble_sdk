import 'dart:typed_data';
import '../../../core/byte_utils.dart';
import '../../../models/workout_data.dart';
import '../../../models/machine_type.dart';

/// 椭圆机数据特性（0x2ACE）的解析器。
class CrossTrainerDataParser {
  CrossTrainerDataParser._();

  /// 从原始 BLE 通知字节中解析椭圆机数据。
  static WorkoutData parse(Uint8List data) {
    if (data.length < 3) {
      return WorkoutData(machineType: MachineType.crossTrainer);
    }

    // 椭圆机使用 24 位标志字段
    final flags = ByteUtils.readUint24(data, 0);
    int offset = 3;

    // 位 0：More Data（0=速度存在）
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

    // 位 2：总距离（Total Distance）存在
    int? totalDistance;
    if (ByteUtils.isBitSet(flags, 2)) {
      totalDistance = ByteUtils.readUint24(data, offset);
      offset += 3;
    }

    // 位 3：步数（Step Count）存在
    int? stepsPerMinute;
    int? averageStepRate;
    if (ByteUtils.isBitSet(flags, 3)) {
      stepsPerMinute = ByteUtils.readUint16(data, offset);
      offset += 2;
      averageStepRate = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 4：步幅计数（Stride Count）存在
    int? strideCount;
    if (ByteUtils.isBitSet(flags, 4)) {
      strideCount = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 5：海拔增益（Elevation Gain）存在
    double? positiveElevGain;
    double? negativeElevGain;
    if (ByteUtils.isBitSet(flags, 5)) {
      positiveElevGain = ByteUtils.readUint16(data, offset) / 10.0;
      offset += 2;
      negativeElevGain = ByteUtils.readUint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 6：坡度和坡道角度（Inclination and Ramp Angle）存在
    double? inclination;
    double? rampAngle;
    if (ByteUtils.isBitSet(flags, 6)) {
      inclination = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
      rampAngle = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 7：阻力等级（Resistance Level）存在
    double? resistanceLevel;
    if (ByteUtils.isBitSet(flags, 7)) {
      resistanceLevel = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 8：瞬时功率（Instantaneous Power）存在
    int? instantaneousPower;
    if (ByteUtils.isBitSet(flags, 8)) {
      instantaneousPower = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 9：平均功率（Average Power）存在
    int? averagePower;
    if (ByteUtils.isBitSet(flags, 9)) {
      averagePower = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 10：消耗热量（Expended Energy）存在
    double? totalEnergy;
    int? energyPerHour;
    int? energyPerMinute;
    if (ByteUtils.isBitSet(flags, 10)) {
      totalEnergy = ByteUtils.readUint16(data, offset).toDouble();
      offset += 2;
      energyPerHour = ByteUtils.readUint16(data, offset);
      offset += 2;
      energyPerMinute = ByteUtils.readUint8(data, offset);
      offset += 1;
    }

    // 位 11：心率（Heart Rate）存在
    int? heartRate;
    if (ByteUtils.isBitSet(flags, 11)) {
      heartRate = ByteUtils.readUint8(data, offset);
      offset += 1;
    }

    // 位 12：代谢当量（Metabolic Equivalent）存在
    double? metabolicEquivalent;
    if (ByteUtils.isBitSet(flags, 12)) {
      metabolicEquivalent = ByteUtils.readUint8(data, offset) / 10.0;
      offset += 1;
    }

    // 位 13：已运动时间（Elapsed Time）存在
    int? elapsedTime;
    if (ByteUtils.isBitSet(flags, 13)) {
      elapsedTime = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 14：剩余时间（Remaining Time）存在
    int? remainingTime;
    if (ByteUtils.isBitSet(flags, 14)) {
      remainingTime = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    return WorkoutData(
      machineType: MachineType.crossTrainer,
      instantaneousSpeed: instantaneousSpeed,
      averageSpeed: averageSpeed,
      totalDistance: totalDistance,
      stepsPerMinute: stepsPerMinute,
      averageStepRate: averageStepRate,
      strideCount: strideCount,
      positiveElevationGain: positiveElevGain,
      negativeElevationGain: negativeElevGain,
      inclination: inclination,
      rampAngle: rampAngle,
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
