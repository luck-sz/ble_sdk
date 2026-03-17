import 'dart:typed_data';
import '../../models/machine_status.dart';
import '../../models/machine_type.dart';
import '../../models/workout_data.dart';
import '../../models/supported_ranges.dart';
import 'es_constants.dart';

/// ES 数据解析器
class EsDataParser {
  /// 验证校验和: XOR of Header, ID, Length, and all Data Body bytes.
  /// 数据包格式: [Header(0xA9), ID, Length, Data0...DataN, Checksum]
  static bool verifyChecksum(Uint8List data) {
    if (data.length < 4) return false;
    
    int header = data[0];
    if (header != EsConstants.header) return false;
    
    int expectedLength = data[2];
    if (data.length != expectedLength + 4) return false; // Header + ID + Len + Data[] + Checksum

    int checksum = header;
    checksum ^= data[1]; // ID
    checksum ^= data[2]; // Length
    
    for (int i = 0; i < expectedLength; i++) {
        checksum ^= data[3 + i]; // Data Body
    }
    
    int receivedChecksum = data[data.length - 1];
    return checksum == receivedChecksum;
  }

  /// 解析心跳数据 (0x02)
  static WorkoutData parseWorkoutData(Uint8List dataBytes) {
    // dataBytes 是去除了头部和校验和后的 Data Body (Length 长度部分)
    // 根据规范 Length 为 13 bytes
    if (dataBytes.length < 13) return WorkoutData(machineType: MachineType.treadmill);

    int hr = dataBytes[0];
    
    // Calories (3 bytes, Big Endian). Unit is 10 calories (0.01 kcal).
    // e.g. 100 units = 1000 calories = 1 kcal.
    int calRaw = (dataBytes[1] << 16) | (dataBytes[2] << 8) | dataBytes[3];
    double calories = calRaw / 100.0;

    // Distance (2 bytes, Big Endian, meters)
    int distance = (dataBytes[4] << 8) | dataBytes[5];

    // Steps (3 bytes, Big Endian)
    int steps = (dataBytes[6] << 16) | (dataBytes[7] << 8) | dataBytes[8];

    // Time (2 bytes, Big Endian, seconds)
    int time = (dataBytes[9] << 8) | dataBytes[10];

    // Lub Dist. is byte 11, 12. Not currently heavily mapped.

    return WorkoutData(
      machineType: MachineType.treadmill, // ES协议默认一般是跑步机
      heartRate: hr,
      totalEnergy: calories,
      totalDistance: distance,
      stepCount: steps,
      elapsedTime: time,
    );
  }

  /// 解析运动状态变更 (0x09)
  static MachineStatus parseStatusChange(Uint8List dataBytes) {
    if (dataBytes.isEmpty) return const MachineStatus(statusCode: MachineStatusCode.rfu);
    
    int s = dataBytes[0];
    switch (s) {
      case 0: return const MachineStatus(statusCode: MachineStatusCode.stoppedOrPausedByUser, controlInfo: 0x01); // Standby => Stopped
      case 1: return const MachineStatus(statusCode: MachineStatusCode.startedOrResumedByUser); // Starting => Started
      case 2: return const MachineStatus(statusCode: MachineStatusCode.startedOrResumedByUser); // Running
      case 3: return const MachineStatus(statusCode: MachineStatusCode.stoppedOrPausedByUser, controlInfo: 0x02); // About to Pause
      case 4: return const MachineStatus(statusCode: MachineStatusCode.stoppedOrPausedByUser, controlInfo: 0x02); // Paused
      case 5: return const MachineStatus(statusCode: MachineStatusCode.stoppedOrPausedByUser, controlInfo: 0x01); // About to Stop
      case 6: return const MachineStatus(statusCode: MachineStatusCode.stoppedOrPausedByUser, controlInfo: 0x01); // Stopped
      default: return const MachineStatus(statusCode: MachineStatusCode.rfu);
    }
  }

  /// 解析错误(0x03)
  static MachineStatus parseError(Uint8List dataBytes) {
    if (dataBytes.length < 2) return const MachineStatus(statusCode: MachineStatusCode.rfu);
    // int code = dataBytes[1]; 文档暂未详情说明，但有错就可以停止

    // 出错我们映射到 stoppedBySafetyKey 或其他统一状态，以便于上层停止 App 数据滚动
    return const MachineStatus(
      statusCode: MachineStatusCode.stoppedBySafetyKey, // 代表硬件出错导致强停
    );
  }

  /// 解析全局同步信息 (0xF2)
  /// [dataBytes] 为 [Unit, SpeedRaw, InclineRaw]
  static Map<String, dynamic> parseSyncInfo(Uint8List dataBytes) {
    if (dataBytes.length < 3) return {};

    // Byte 1: Speed (Scale 10x)
    double speed = dataBytes[1] / 10.0;
    // Byte 2: Incline (Scale 1x)
    double incline = dataBytes[2].toDouble();
    // Byte 0: Unit (1=Metric, 2=Imperial)
    bool isMetric = dataBytes[0] == 1;

    return {
      'speed': speed,
      'incline': incline,
      'isMetric': isMetric,
    };
  }

  /// 解析速度和坡度范围 (0x0A)
  /// [dataBytes] 为 [MinSpeed, MaxSpeed, MinIncline, MaxIncline]
  static SupportedRanges parseRangeInfo(Uint8List dataBytes) {
    if (dataBytes.length < 4) return const SupportedRanges();

    double minSpeed = dataBytes[0] / 10.0;
    double maxSpeed = dataBytes[1] / 10.0;
    double minIncline = dataBytes[2].toDouble();
    double maxIncline = dataBytes[3].toDouble();

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
