import 'dart:typed_data';
import '../../../core/byte_utils.dart';
import '../../../models/workout_data.dart';
import '../../../models/machine_type.dart';

/// 跑步机数据特性（0x2ACD）的解析器。
class TreadmillDataParser {
  TreadmillDataParser._();

  /// 从原始 BLE 通知字节中解析跑步机数据。
  ///
  /// 数据格式：首先是一个 16 位标志字段，后面跟随可变长度的
  /// 数据字段，具体字段的存在取决于标志位的设置。
  static WorkoutData parse(Uint8List data) {
    if (data.length < 2) {
      return WorkoutData(machineType: MachineType.treadmill);
    }

    final flags = ByteUtils.readUint16(data, 0);
    int offset = 2;

    // 位 0：More Data（0=存在，1=不存在）—— 注意：逻辑取反！
    // 当 More Data 为 0 时，瞬时速度为必填字段
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

    // 位 3：坡度和坡道角度（Inclination and Ramp Angle）存在
    double? inclination;
    double? rampAngle;
    if (ByteUtils.isBitSet(flags, 3)) {
      inclination = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
      rampAngle = ByteUtils.readSint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 4：海拔增益（Elevation Gain）存在
    double? positiveElevGain;
    double? negativeElevGain;
    if (ByteUtils.isBitSet(flags, 4)) {
      positiveElevGain = ByteUtils.readUint16(data, offset) / 10.0;
      offset += 2;
      negativeElevGain = ByteUtils.readUint16(data, offset) / 10.0;
      offset += 2;
    }

    // 位 5：瞬时配速（Instantaneous Pace）存在
    double? instantaneousPace;
    if (ByteUtils.isBitSet(flags, 5)) {
      instantaneousPace = ByteUtils.readUint8(data, offset) / 10.0;
      offset += 1;
    }

    // 位 6：平均配速（Average Pace）存在
    double? averagePace;
    if (ByteUtils.isBitSet(flags, 6)) {
      averagePace = ByteUtils.readUint8(data, offset) / 10.0;
      offset += 1;
    }

    // 位 7：消耗热量（Expended Energy）存在
    int? totalEnergy;
    int? energyPerHour;
    int? energyPerMinute;
    if (ByteUtils.isBitSet(flags, 7)) {
      totalEnergy = ByteUtils.readUint16(data, offset);
      offset += 2;
      energyPerHour = ByteUtils.readUint16(data, offset);
      offset += 2;
      energyPerMinute = ByteUtils.readUint8(data, offset);
      offset += 1;
    }

    // 位 8：心率（Heart Rate）存在
    int? heartRate;
    if (ByteUtils.isBitSet(flags, 8)) {
      heartRate = ByteUtils.readUint8(data, offset);
      offset += 1;
    }

    // 位 9：代谢当量（Metabolic Equivalent）存在
    double? metabolicEquivalent;
    if (ByteUtils.isBitSet(flags, 9)) {
      metabolicEquivalent = ByteUtils.readUint8(data, offset) / 10.0;
      offset += 1;
    }

    // 位 10：已运动时间（Elapsed Time）存在
    int? elapsedTime;
    if (ByteUtils.isBitSet(flags, 10)) {
      elapsedTime = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 11：剩余时间（Remaining Time）存在
    int? remainingTime;
    if (ByteUtils.isBitSet(flags, 11)) {
      remainingTime = ByteUtils.readUint16(data, offset);
      offset += 2;
    }

    // 位 12：皮带受力和输出功率（Force on Belt and Power Output）存在
    int? forceOnBelt;
    int? powerOutput;
    if (ByteUtils.isBitSet(flags, 12)) {
      forceOnBelt = ByteUtils.readSint16(data, offset);
      offset += 2;
      powerOutput = ByteUtils.readSint16(data, offset);
      offset += 2;
    }

    // 位 13：步数（Steps）存在（EQI 扩展 - uint24）
    int? stepCount;
    if (ByteUtils.isBitSet(flags, 13)) {
      stepCount = ByteUtils.readUint24(data, offset);
      offset += 3;
    }

    return WorkoutData(
      machineType: MachineType.treadmill,
      instantaneousSpeed: instantaneousSpeed,
      averageSpeed: averageSpeed,
      totalDistance: totalDistance,
      inclination: inclination,
      rampAngle: rampAngle,
      positiveElevationGain: positiveElevGain,
      negativeElevationGain: negativeElevGain,
      instantaneousPace: instantaneousPace,
      averagePace: averagePace,
      totalEnergy: totalEnergy,
      energyPerHour: energyPerHour,
      energyPerMinute: energyPerMinute,
      heartRate: heartRate,
      metabolicEquivalent: metabolicEquivalent,
      elapsedTime: elapsedTime,
      remainingTime: remainingTime,
      forceOnBelt: forceOnBelt,
      powerOutput: powerOutput,
      stepCount: stepCount,
    );
  }
}
