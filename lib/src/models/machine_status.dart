import 'dart:typed_data';
import '../core/byte_utils.dart';

/// 来自健身设备状态特性（0x2ADA）的设备状态通知码。
enum MachineStatusCode {
  /// 保留供将来使用（RFU）
  rfu(0x00),

  /// 设备已重置。
  reset(0x01),

  /// 用户停止或暂停。
  stoppedOrPausedByUser(0x02),

  /// 由安全键停止。
  stoppedBySafetyKey(0x03),

  /// 用户开始或继续。
  startedOrResumedByUser(0x04),

  /// 目标速度已更改。
  targetSpeedChanged(0x05),

  /// 目标坡度已更改。
  targetInclineChanged(0x06),

  /// 目标阻力等级已更改。
  targetResistanceLevelChanged(0x07);

  final int code;
  const MachineStatusCode(this.code);

  static MachineStatusCode? fromCode(int code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// 已解析的设备状态通知。
class MachineStatus {
  /// 状态码。
  final MachineStatusCode statusCode;

  /// 针对 stoppedOrPausedByUser：0x01=停止，0x02=暂停
  final int? controlInfo;

  /// 针对 targetSpeedChanged：新速度，单位 km/h
  final double? newTargetSpeed;

  /// 针对 targetInclineChanged：新坡度，单位 %
  final double? newTargetIncline;

  /// 针对 targetResistanceLevelChanged：新阻力值
  final int? newTargetResistance;

  /// 原始参数字节。
  final Uint8List? rawParameter;

  const MachineStatus({
    required this.statusCode,
    this.controlInfo,
    this.newTargetSpeed,
    this.newTargetIncline,
    this.newTargetResistance,
    this.rawParameter,
  });

  /// 设备是否已停止（而非暂停）。
  bool get isStopped =>
      statusCode == MachineStatusCode.stoppedOrPausedByUser && controlInfo == 0x01;

  /// 设备是否已暂停（而非停止）。
  bool get isPaused =>
      statusCode == MachineStatusCode.stoppedOrPausedByUser && controlInfo == 0x02;

  /// 从原始字节解析设备状态。
  factory MachineStatus.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      return const MachineStatus(statusCode: MachineStatusCode.rfu);
    }

    final statusCode =
        MachineStatusCode.fromCode(data[0]) ?? MachineStatusCode.rfu;
    int? controlInfo;
    double? newTargetSpeed;
    double? newTargetIncline;
    int? newTargetResistance;

    if (data.length > 1) {
      switch (statusCode) {
        case MachineStatusCode.stoppedOrPausedByUser:
          controlInfo = data[1];
          break;
        case MachineStatusCode.targetSpeedChanged:
          newTargetSpeed = ByteUtils.readUint16(data, 1) / 100.0;
          break;
        case MachineStatusCode.targetInclineChanged:
          newTargetIncline = ByteUtils.readSint16(data, 1) / 10.0;
          break;
        case MachineStatusCode.targetResistanceLevelChanged:
          newTargetResistance = data[1];
          break;
        default:
          break;
      }
    }

    return MachineStatus(
      statusCode: statusCode,
      controlInfo: controlInfo,
      newTargetSpeed: newTargetSpeed,
      newTargetIncline: newTargetIncline,
      newTargetResistance: newTargetResistance,
      rawParameter: data.length > 1 ? data.sublist(1) : null,
    );
  }

  @override
  String toString() {
    final extra = <String>[];
    if (controlInfo != null) {
      extra.add(controlInfo == 0x01 ? 'stop' : 'pause');
    }
    if (newTargetSpeed != null) extra.add('speed=${newTargetSpeed}km/h');
    if (newTargetIncline != null) extra.add('incline=${newTargetIncline}%');
    if (newTargetResistance != null) extra.add('resistance=$newTargetResistance');
    return 'MachineStatus(${statusCode.name}${extra.isNotEmpty ? ', ${extra.join(', ')}' : ''})';
  }
}
