import 'machine_type.dart';

/// 通用运动数据模型。
///
/// 这是一个统一的数据结构，可以承载来自任意设备类型的数据。
/// 不适用于特定设备类型的字段将为 null。
class WorkoutData {
  /// 此数据来源的设备类型。
  final MachineType machineType;

  /// 瞬时速度，单位 km/h。
  final double? instantaneousSpeed;

  /// 平均速度，单位 km/h。
  final double? averageSpeed;

  /// 总距离，单位米。
  final int? totalDistance;

  /// 坡度，单位百分比（%）。
  final double? inclination;

  /// 坡道角度，单位度。
  final double? rampAngle;

  /// 正向海拔增益，单位米。
  final double? positiveElevationGain;

  /// 负向海拔增益，单位米。
  final double? negativeElevationGain;

  /// 瞬时配速，单位 km/m。
  final double? instantaneousPace;

  /// 平均配速，单位 km/m。
  final double? averagePace;

  /// 总消耗热量，单位 kcal。
  final double? totalEnergy;

  /// 每小时消耗热量，单位 kcal。
  final int? energyPerHour;

  /// 每分钟消耗热量，单位 kcal。
  final int? energyPerMinute;

  /// 心率，单位 bpm。
  final int? heartRate;

  /// 代谢当量（MET）。
  final double? metabolicEquivalent;

  /// 已运动时间，单位秒。
  final int? elapsedTime;

  /// 剩余时间，单位秒。
  final int? remainingTime;

  /// 皮带受力，单位牛顿（N）。
  final int? forceOnBelt;

  /// 输出功率，单位瓦特（W）。
  final int? powerOutput;

  /// 步数。
  final int? stepCount;

  /// 步幅计数。
  final int? strideCount;

  /// 瞬时踏频，单位 rpm（适用于单车）。
  final double? instantaneousCadence;

  /// 平均踏频，单位 rpm。
  final double? averageCadence;

  /// 阻力等级。
  final double? resistanceLevel;

  /// 瞬时功率，单位瓦特（适用于单车/椭圆机/划船机）。
  final int? instantaneousPower;

  /// 平均功率，单位瓦特。
  final int? averagePower;

  /// 划频（适用于划船机），单位次/分钟。
  final double? strokeRate;

  /// 划次计数（适用于划船机）。
  final int? strokeCount;

  /// 平均划频，单位次/分钟。
  final double? averageStrokeRate;

  /// 每分钟步数（椭圆机）。
  final int? stepsPerMinute;

  /// 平均步频（椭圆机）。
  final int? averageStepRate;

  /// 数据接收时的原始时间戳。
  final DateTime timestamp;

  WorkoutData({
    required this.machineType,
    this.instantaneousSpeed,
    this.averageSpeed,
    this.totalDistance,
    this.inclination,
    this.rampAngle,
    this.positiveElevationGain,
    this.negativeElevationGain,
    this.instantaneousPace,
    this.averagePace,
    this.totalEnergy,
    this.energyPerHour,
    this.energyPerMinute,
    this.heartRate,
    this.metabolicEquivalent,
    this.elapsedTime,
    this.remainingTime,
    this.forceOnBelt,
    this.powerOutput,
    this.stepCount,
    this.strideCount,
    this.instantaneousCadence,
    this.averageCadence,
    this.resistanceLevel,
    this.instantaneousPower,
    this.averagePower,
    this.strokeRate,
    this.strokeCount,
    this.averageStrokeRate,
    this.stepsPerMinute,
    this.averageStepRate,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    final parts = <String>['WorkoutData(type=${machineType.englishName}'];
    if (instantaneousSpeed != null) {
      parts.add('speed=${instantaneousSpeed}km/h');
    }
    if (totalDistance != null) parts.add('dist=${totalDistance}m');
    if (totalEnergy != null) parts.add('energy=${totalEnergy!.toStringAsFixed(1)}kcal');
    if (heartRate != null) parts.add('hr=${heartRate}bpm');
    if (elapsedTime != null) parts.add('time=${elapsedTime}s');
    if (instantaneousPower != null) parts.add('power=${instantaneousPower}W');
    if (instantaneousCadence != null) {
      parts.add('cadence=${instantaneousCadence}rpm');
    }
    parts.add(')');
    return parts.join(', ');
  }
}
