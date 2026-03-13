import 'dart:typed_data';
import '../../../core/byte_utils.dart';

/// EQI 设备的运动模式。
enum EqiWorkoutMode {
  /// 未知模式。
  unknown(0x00),

  /// 时间目标模式（时间目标模式）。
  time(0x01),

  /// 距离目标模式（距离目标模式）。
  distance(0x02),

  /// 热量目标模式（热量目标模式）。
  calorie(0x03),

  /// 次数目标模式（次数目标模式）。
  count(0x04);

  final int code;
  const EqiWorkoutMode(this.code);

  static EqiWorkoutMode fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return EqiWorkoutMode.unknown;
  }
}

/// EQI 模式状态扩展特性。
/// UUID: a75b1f95-a4a1-75a4-2871-6daedc8e5ca0
///
/// 包含以下信息：
/// - 支持的模式位掩码
/// - 当前运动模式
/// - 模式目标值
class EqiModeState {
  static const String uuid = 'a75b1f95-a4a1-75a4-2871-6daedc8e5ca0';

  /// 支持的模式位掩码。
  /// 位 0：时间，位 1：距离，位 2：热量，位 3：次数。
  final int supportedModes;

  /// 当前运动模式。
  final EqiWorkoutMode currentMode;

  /// 当前模式的目标值。
  /// 单位取决于模式：
  /// - 时间模式：秒
  /// - 距离模式：米
  /// - 热量模式：千卡（kcal）
  /// - 次数模式：次
  final int? modeTarget;

  const EqiModeState({
    required this.supportedModes,
    required this.currentMode,
    this.modeTarget,
  });

  /// 是否支持时间模式。
  bool get isTimeModeSupported => ByteUtils.isBitSet(supportedModes, 0);

  /// 是否支持距离模式。
  bool get isDistanceModeSupported => ByteUtils.isBitSet(supportedModes, 1);

  /// 是否支持热量模式。
  bool get isCalorieModeSupported => ByteUtils.isBitSet(supportedModes, 2);

  /// 是否支持次数模式。
  bool get isCountModeSupported => ByteUtils.isBitSet(supportedModes, 3);

  /// 从原始字节解析。
  factory EqiModeState.fromBytes(Uint8List data) {
    if (data.isEmpty) {
      return const EqiModeState(
        supportedModes: 0,
        currentMode: EqiWorkoutMode.unknown,
      );
    }

    final supportedModes = data[0];
    final currentMode = data.length > 1
        ? EqiWorkoutMode.fromCode(data[1])
        : EqiWorkoutMode.unknown;
    final modeTarget = data.length >= 4
        ? ByteUtils.readUint16(data, 2)
        : null;

    return EqiModeState(
      supportedModes: supportedModes,
      currentMode: currentMode,
      modeTarget: modeTarget,
    );
  }

  /// 编码为字节以用于写入模式和目标值。
  Uint8List toBytes() {
    final bytes = <int>[currentMode.code];
    if (modeTarget != null) {
      bytes.addAll(ByteUtils.writeUint16(modeTarget!));
    }
    return Uint8List.fromList(bytes);
  }

  @override
  String toString() =>
      'EqiModeState(mode=${currentMode.name}, target=$modeTarget, '
      'supported=0x${supportedModes.toRadixString(16)})';
}
