import 'dart:typed_data';
import '../../core/ble_device.dart';
import '../../models/control_command.dart';
import 'ftms_constants.dart';

/// 负责向健身设备控制点（0x2AD9）写入数据并解析响应。
class FtmsControlPoint {
  final BleDevice _device;

  FtmsControlPoint(this._device);

  /// 发送控制命令并返回响应。
  ///
  /// 控制点采用 Write+Indicate 方式，即写入命令后
  /// 等待 Indication 响应返回。
  Future<ControlResponse> sendCommand(ControlCommand command) async {
    final bytes = command.toBytes();

    await _device.writeCharacteristic(
      FtmsConstants.serviceUuid,
      FtmsConstants.fitnessMachineControlPointUuid,
      bytes,
      withResponse: true,
    );

    // 响应通过 Indication 方式到达，将由
    // FtmsProtocol 类通过订阅来处理。
    // 此处返回占位响应，实际响应通过数据流处理。
    return ControlResponse(
      requestOpCode: command.opCode,
      resultCode: ControlResultCode.success,
    );
  }

  /// 请求控制设备。
  Future<ControlResponse> requestControl() =>
      sendCommand(ControlCommand.requestControl());

  /// 重置设备。
  Future<ControlResponse> reset() =>
      sendCommand(ControlCommand.reset());

  /// 设置目标速度，单位 km/h。
  Future<ControlResponse> setTargetSpeed(double speedKmh) =>
      sendCommand(ControlCommand.setTargetSpeed(speedKmh));

  /// 设置目标坡度，单位 %。
  Future<ControlResponse> setTargetInclination(double inclinationPercent) =>
      sendCommand(ControlCommand.setTargetInclination(inclinationPercent));

  /// 设置目标阻力等级。
  Future<ControlResponse> setTargetResistance(double resistance) =>
      sendCommand(ControlCommand.setTargetResistance(resistance));

  /// 设置目标功率，单位瓦特（W）。
  Future<ControlResponse> setTargetPower(int powerWatts) =>
      sendCommand(ControlCommand.setTargetPower(powerWatts));

  /// 开始或继续运动。
  Future<ControlResponse> startOrResume() =>
      sendCommand(ControlCommand.startOrResume());

  /// 停止设备。
  Future<ControlResponse> stop() =>
      sendCommand(ControlCommand.stop());

  /// 暂停设备。
  Future<ControlResponse> pause() =>
      sendCommand(ControlCommand.pause());
}
