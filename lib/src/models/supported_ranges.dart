import 'dart:typed_data';
import '../core/byte_utils.dart';

/// 从设备读取的支持参数范围。
class SupportedRanges {
  final SpeedRange? speedRange;
  final InclinationRange? inclinationRange;
  final ResistanceRange? resistanceRange;
  final PowerRange? powerRange;
  final HeartRateRange? heartRateRange;

  const SupportedRanges({
    this.speedRange,
    this.inclinationRange,
    this.resistanceRange,
    this.powerRange,
    this.heartRateRange,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (speedRange != null) parts.add('speed=$speedRange');
    if (inclinationRange != null) parts.add('incline=$inclinationRange');
    if (resistanceRange != null) parts.add('resistance=$resistanceRange');
    if (powerRange != null) parts.add('power=$powerRange');
    if (heartRateRange != null) parts.add('hr=$heartRateRange');
    return 'SupportedRanges(${parts.join(', ')})';
  }
}

/// 支持的速度范围（0x2AD4）。
/// 值以 km/h 为单位（原始值 * 0.01）。
class SpeedRange {
  final double minimum;
  final double maximum;
  final double increment;

  const SpeedRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  factory SpeedRange.fromBytes(Uint8List data) {
    return SpeedRange(
      minimum: ByteUtils.readUint16(data, 0) / 100.0,
      maximum: ByteUtils.readUint16(data, 2) / 100.0,
      increment: ByteUtils.readUint16(data, 4) / 100.0,
    );
  }

  @override
  String toString() => 'SpeedRange($minimum-${maximum}km/h, step=$increment)';
}

/// 支持的坡度范围（0x2AD5）。
/// 值以 % 为单位（原始值 * 0.1）。
class InclinationRange {
  final double minimum;
  final double maximum;
  final double increment;

  const InclinationRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  factory InclinationRange.fromBytes(Uint8List data) {
    return InclinationRange(
      minimum: ByteUtils.readSint16(data, 0) / 10.0,
      maximum: ByteUtils.readSint16(data, 2) / 10.0,
      increment: ByteUtils.readUint16(data, 4) / 10.0,
    );
  }

  @override
  String toString() =>
      'InclinationRange($minimum-$maximum%, step=$increment)';
}

/// 支持的阻力等级范围（0x2AD6）。
class ResistanceRange {
  final double minimum;
  final double maximum;
  final double increment;

  const ResistanceRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  factory ResistanceRange.fromBytes(Uint8List data) {
    return ResistanceRange(
      minimum: ByteUtils.readSint16(data, 0).toDouble(),
      maximum: ByteUtils.readSint16(data, 2).toDouble(),
      increment: ByteUtils.readUint16(data, 4).toDouble(),
    );
  }

  @override
  String toString() => 'ResistanceRange($minimum-$maximum, step=$increment)';
}

/// 支持的功率范围（0x2AD8）。
/// 值以瓦特（W）为单位。
class PowerRange {
  final int minimum;
  final int maximum;
  final int increment;

  const PowerRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  factory PowerRange.fromBytes(Uint8List data) {
    return PowerRange(
      minimum: ByteUtils.readSint16(data, 0),
      maximum: ByteUtils.readSint16(data, 2),
      increment: ByteUtils.readUint16(data, 4),
    );
  }

  @override
  String toString() => 'PowerRange($minimum-${maximum}W, step=$increment)';
}

/// 支持的心率范围（0x2AD7）。
/// 值以 bpm 为单位。
class HeartRateRange {
  final int minimum;
  final int maximum;
  final int increment;

  const HeartRateRange({
    required this.minimum,
    required this.maximum,
    required this.increment,
  });

  factory HeartRateRange.fromBytes(Uint8List data) {
    return HeartRateRange(
      minimum: ByteUtils.readUint8(data, 0),
      maximum: ByteUtils.readUint8(data, 1),
      increment: ByteUtils.readUint8(data, 2),
    );
  }

  @override
  String toString() => 'HeartRateRange($minimum-${maximum}bpm, step=$increment)';
}
