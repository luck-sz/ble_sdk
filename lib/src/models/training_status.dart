import 'dart:typed_data';
import '../core/byte_utils.dart';

/// 来自训练状态特性（0x2AD3）的训练状态码。
enum TrainingStatusCode {
  /// 其他/未知状态。
  other(0x00),

  /// 空闲。
  idle(0x01),

  /// 热身中（EQI 未使用）。
  warmingUp(0x02),

  /// 低强度间歇（EQI 未使用）。
  lowIntensityInterval(0x03),

  /// 高强度间歇（EQI 未使用）。
  highIntensityInterval(0x04),

  /// 恢复间歇（EQI 未使用）。
  recoveryInterval(0x05),

  /// 等长运动（EQI 未使用）。
  isometric(0x06),

  /// 心率控制（EQI 未使用）。
  heartRateControl(0x07),

  /// 体能测试（EQI 未使用）。
  fitnessTest(0x08),

  /// 速度超出范围（EQI 未使用）。
  speedOutsideRange(0x09),

  /// 冷却放松（EQI 未使用）。
  coolDown(0x0A),

  /// 瓦特控制（EQI 未使用）。
  wattControl(0x0B),

  /// 手动模式（EQI 未使用）。
  manualMode(0x0C),

  /// 运动中。
  running(0x0D),

  /// 运动前倒计时。
  preWorkoutCountdown(0x0E),

  /// 运动后结果/汇总。
  postWorkoutResult(0x0F),

  /// 已暂停。
  paused(0x10),

  /// 已停止。
  stopped(0x11);

  final int code;
  const TrainingStatusCode(this.code);

  static TrainingStatusCode fromCode(int code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return TrainingStatusCode.other;
  }
}

/// 来自训练状态特性的训练状态数据。
class TrainingStatus {
  /// 当前训练状态。
  final TrainingStatusCode status;

  /// 可选状态字符串（当标志位 0 被置位时存在）。
  final String? statusString;

  /// 原始数据字节。
  final Uint8List rawData;

  const TrainingStatus({
    required this.status,
    this.statusString,
    required this.rawData,
  });

  /// 从原始字节解析训练状态。
  factory TrainingStatus.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      return TrainingStatus(
        status: TrainingStatusCode.other,
        rawData: data,
      );
    }

    // 字节 0：标志位
    final flags = data[0];
    final hasString = ByteUtils.isBitSet(flags, 0);

    // 字节 1：训练状态
    final statusCode = data.length > 1
        ? TrainingStatusCode.fromCode(data[1])
        : TrainingStatusCode.other;

    // 字节 2+：可选字符串
    String? statusString;
    if (hasString && data.length > 2) {
      statusString = String.fromCharCodes(data.sublist(2));
    }

    return TrainingStatus(
      status: statusCode,
      statusString: statusString,
      rawData: data,
    );
  }

  /// 设备当前是否处于活跃状态（运动中/运动前倒计时）。
  bool get isActive =>
      status == TrainingStatusCode.running ||
      status == TrainingStatusCode.preWorkoutCountdown;

  @override
  String toString() => 'TrainingStatus(${status.name})';
}
