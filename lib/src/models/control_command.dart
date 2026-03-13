import 'dart:typed_data';
import '../core/byte_utils.dart';

/// 可发送给健身设备的控制命令操作码。
enum ControlOpCode {
  /// 请求控制设备（必须）。
  requestControl(0x00),

  /// 重置设备（必须）。
  reset(0x01),

  /// 设置目标速度（uint16，单位 0.01 km/h）。
  setTargetSpeed(0x02),

  /// 设置目标坡度（sint16，单位 0.1%）。
  setTargetInclination(0x03),

  /// 设置目标阻力等级（uint8，单位 0.1）。
  setTargetResistance(0x04),

  /// 设置目标功率（sint16，单位 1W）。
  setTargetPower(0x05),

  /// 开始或继续（必须）。
  startOrResume(0x07),

  /// 停止或暂停（必须）。参数：0x01=停止，0x02=暂停。
  stopOrPause(0x08),

  /// 设备返回的响应码。
  response(0x80);

  final int code;
  const ControlOpCode(this.code);

  static ControlOpCode? fromCode(int code) {
    for (final op in values) {
      if (op.code == code) return op;
    }
    return null;
  }
}

/// 设备返回的控制结果码。
enum ControlResultCode {
  /// 操作成功。
  success(0x01),

  /// 不支持该操作码。
  opCodeNotSupported(0x02),

  /// 无效参数。
  invalidParameter(0x03),

  /// 操作失败。
  operationFailed(0x04),

  /// 不允许控制。
  controlNotPermitted(0x05);

  final int code;
  const ControlResultCode(this.code);

  static ControlResultCode? fromCode(int code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// 停止/暂停参数值。
enum StopPauseParam {
  stop(0x01),
  pause(0x02);

  final int code;
  const StopPauseParam(this.code);
}

/// 发送给健身设备控制点的命令。
class ControlCommand {
  final ControlOpCode opCode;
  final Uint8List? parameter;

  const ControlCommand({required this.opCode, this.parameter});

  /// 创建一个「请求控制」命令。
  factory ControlCommand.requestControl() =>
      const ControlCommand(opCode: ControlOpCode.requestControl);

  /// 创建一个「重置」命令。
  factory ControlCommand.reset() =>
      const ControlCommand(opCode: ControlOpCode.reset);

  /// 创建一个「设置目标速度」命令。
  /// [speedKmh] 为目标速度，单位 km/h。
  factory ControlCommand.setTargetSpeed(double speedKmh) {
    final rawValue = (speedKmh * 100).round();
    return ControlCommand(
      opCode: ControlOpCode.setTargetSpeed,
      parameter: ByteUtils.writeUint16(rawValue),
    );
  }

  /// 创建一个「设置目标坡度」命令。
  /// [inclinationPercent] 为目标坡度，单位 %。
  factory ControlCommand.setTargetInclination(double inclinationPercent) {
    final rawValue = (inclinationPercent * 10).round();
    return ControlCommand(
      opCode: ControlOpCode.setTargetInclination,
      parameter: ByteUtils.writeSint16(rawValue),
    );
  }

  /// 创建一个「设置目标阻力」命令。
  /// [resistance] 为目标阻力等级。
  factory ControlCommand.setTargetResistance(double resistance) {
    final rawValue = (resistance * 10).round();
    return ControlCommand(
      opCode: ControlOpCode.setTargetResistance,
      parameter: ByteUtils.writeUint8(rawValue),
    );
  }

  /// 创建一个「设置目标功率」命令。
  /// [powerWatts] 为目标功率，单位瓦特（W）。
  factory ControlCommand.setTargetPower(int powerWatts) {
    return ControlCommand(
      opCode: ControlOpCode.setTargetPower,
      parameter: ByteUtils.writeSint16(powerWatts),
    );
  }

  /// 创建一个「开始/继续」命令。
  factory ControlCommand.startOrResume() =>
      const ControlCommand(opCode: ControlOpCode.startOrResume);

  /// 创建一个「停止」命令。
  factory ControlCommand.stop() => ControlCommand(
        opCode: ControlOpCode.stopOrPause,
        parameter: ByteUtils.writeUint8(StopPauseParam.stop.code),
      );

  /// 创建一个「暂停」命令。
  factory ControlCommand.pause() => ControlCommand(
        opCode: ControlOpCode.stopOrPause,
        parameter: ByteUtils.writeUint8(StopPauseParam.pause.code),
      );

  /// 将此命令编码为字节数组，以发送到控制点。
  Uint8List toBytes() {
    if (parameter != null) {
      return Uint8List.fromList([opCode.code, ...parameter!]);
    }
    return Uint8List.fromList([opCode.code]);
  }

  @override
  String toString() => 'ControlCommand(opCode=${opCode.name}, params=$parameter)';
}

/// 来自健身设备控制点的响应。
class ControlResponse {
  final ControlOpCode requestOpCode;
  final ControlResultCode resultCode;
  final Uint8List? responseParameter;

  const ControlResponse({
    required this.requestOpCode,
    required this.resultCode,
    this.responseParameter,
  });

  /// 响应是否表示成功。
  bool get isSuccess => resultCode == ControlResultCode.success;

  /// 从原始字节解析控制点响应。
  /// 格式：[0x80, RequestOpCode, ResultCode, ...可选参数]
  factory ControlResponse.fromBytes(Uint8List data) {
    if (data.length < 3 || data[0] != ControlOpCode.response.code) {
      return ControlResponse(
        requestOpCode: ControlOpCode.response,
        resultCode: ControlResultCode.operationFailed,
      );
    }
    return ControlResponse(
      requestOpCode: ControlOpCode.fromCode(data[1]) ?? ControlOpCode.response,
      resultCode: ControlResultCode.fromCode(data[2]) ?? ControlResultCode.operationFailed,
      responseParameter: data.length > 3 ? data.sublist(3) : null,
    );
  }

  @override
  String toString() =>
      'ControlResponse(op=${requestOpCode.name}, result=${resultCode.name})';
}
