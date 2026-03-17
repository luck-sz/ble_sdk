import 'dart:typed_data';

import '../../core/byte_utils.dart';
import '../../models/machine_status.dart';
import '../../models/machine_type.dart';
import '../../models/supported_ranges.dart';
import '../../models/workout_data.dart';
import 'efc_constants.dart';

class EfcDataParser {
  /// 校验和算法：所有字节的 XOR 异或。
  static bool verifyChecksum(Uint8List data) {
    if (data.length < 5) return false;
    int expectedChecksum = data[data.length - 1];
    int calculatedChecksum = 0;
    for (int i = 0; i < data.length - 1; i++) {
      calculatedChecksum ^= data[i];
    }
    return calculatedChecksum == expectedChecksum;
  }

  /// 从 EFC 协议数据中解析出 WorkoutData。
  /// cmd=0x02 是运动数据。
  static WorkoutData? parseWorkoutData(Uint8List data) {
    if (data.length < 5 || data[0] != EfcConstants.headerRx) return null;
    if (!verifyChecksum(data)) return null;

    int cmd = data[1];
    if (cmd != 0x02) return null; // 只解析 cmd=0x02 为运动数据

    int len = data[2];
    int offset = 3;

    int timeSeconds = 0;
    double? speed;
    double? incline;
    int distance = 0;
    int calRaw = 0;
    int steps = 0;
    int? heartRate;

    try {
      if (len == 0x0B) {
        // V1 格式: Time(2), Speed(1), Incline(1), Dist(2), Cal(2), Steps(2), HR(1)
        timeSeconds = ByteUtils.readUint16BE(data, offset);
        speed = data[offset + 2] / 10.0;
        incline = data[offset + 3].toDouble();
        distance = ByteUtils.readUint16BE(data, offset + 4);
        calRaw = ByteUtils.readUint16BE(data, offset + 6);
        steps = ByteUtils.readUint16BE(data, offset + 8);
        heartRate = data[offset + 10];
      } else {
        // V2 格式 (默认): Time(2), Dist(2), Cal(2), Steps(2), HR(1), Mode(1), Target(2)
        // 注意: 部分极简 V2 可能是 10 字节，通用逻辑如下
        timeSeconds = ByteUtils.readUint16BE(data, offset);
        distance = ByteUtils.readUint16BE(data, offset + 2);
        calRaw = ByteUtils.readUint16BE(data, offset + 4);
        steps = ByteUtils.readUint16BE(data, offset + 6);
        heartRate = data[offset + 8];
      }

      // 根据用户反馈: 机器显示 1 cal 时期望 demo 显示 0.001 kcal
      // 意味着原始单位极可能是 1 calorie (而不是文档写的 0.1 kcal)
      double totalEnergyKcal = calRaw / 1000.0;

      return WorkoutData(
        machineType: MachineType.treadmill,
        elapsedTime: timeSeconds,
        instantaneousSpeed: speed,
        inclination: incline,
        totalDistance: distance,
        totalEnergy: totalEnergyKcal,
        stepCount: steps,
        heartRate: heartRate,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      // 防止数组越界
      return null;
    }
  }

  /// 从 EFC 协议数据中解析出 MachineStatus。
  /// cmd=0x01 包含状态。
  static MachineStatus? parseMachineStatus(Uint8List data) {
    if (data.length < 5 || data[0] != EfcConstants.headerRx) return null;
    if (!verifyChecksum(data)) return null;

    int cmd = data[1];
    if (cmd != 0x01) return null; // 0x01 is Movement Status (RX)

    // BYTE 4: 当前速度 (0.1), BYTE 5: 当前坡度 (1)
    int offset = 3;
    double currentSpeed = data[offset + 4] / 10.0;
    double currentIncline = data[offset + 5].toDouble();

    // 映射状态字节 (BYTE 6)
    int statusByte = data[offset + 6];
    // TODO: 完善状态解析，暂先返回带参数的状态以感知速度变化
    return MachineStatus(
      statusCode: MachineStatusCode.rfu,
      newTargetSpeed: currentSpeed,
      newTargetIncline: currentIncline,
    );
  }

  /// 从 EFC 0x01 数据包中解析支持的范围。
  /// [data] 为完整的数据包 [Header, Cmd, Len, Data..., CS]
  static SupportedRanges? parseSupportedRanges(Uint8List data) {
    if (data.length < 9 || data[1] != 0x01) return null;

    // 根据文档：
    // Byte 3: 最高速度 (0.1)
    // Byte 4: 最低速度 (0.1)
    // Byte 5: 最高坡度 (1)
    // Byte 6: 最低坡度 (1)
    double maxSpeed = data[3] / 10.0;
    double minSpeed = data[4] / 10.0;
    double maxIncline = data[5].toDouble();
    double minIncline = data[6].toDouble();

    // 防止无效数据 (0)
    if (maxSpeed == 0) return null;

    return SupportedRanges(
      speedRange: SpeedRange(
        minimum: minSpeed,
        maximum: maxSpeed,
        increment: 0.1,
      ),
      inclinationRange: InclinationRange(
        minimum: minIncline,
        maximum: maxIncline,
        increment: 1.0,
      ),
    );
  }
}
