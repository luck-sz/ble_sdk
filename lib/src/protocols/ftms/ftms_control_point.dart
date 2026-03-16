import 'dart:async';
import 'dart:typed_data';
import 'dart:developer' as developer;
import '../../core/ble_device.dart';
import '../../models/control_command.dart';
import 'ftms_constants.dart';

/// 负责向健身设备控制点（0x2AD9）写入数据并解析响应。
class FtmsControlPoint {
  static const String _tag = "BleSdk";
  final BleDevice _device;

  // 用于协调发送命令和等待响应的 Completer
  Completer<ControlResponse>? _pendingResponse;

  // 超时时间
  static const Duration _commandTimeout = Duration(seconds: 5);

  FtmsControlPoint(this._device);

  /// 处理从设备发来的控制点响应数据 (Indication)。
  ///
  /// 此方法应由 FtmsProtocol 在收到 0x2AD9 特征值通知时调用。
  void handleControlPointResponse(Uint8List data) {
    if (_pendingResponse == null || _pendingResponse!.isCompleted) return;

    final response = ControlResponse.fromBytes(data);
    developer.log(
      "[$_tag] Received control point response: $response",
      name: _tag,
    );

    // 我们在此将其完成
    _pendingResponse!.complete(response);
  }

  /// 发送控制命令并返回响应。
  ///
  /// 控制点采用 Write+Indication 方式，即写入命令后
  /// 等待 Indication 响应返回。
  Future<ControlResponse> sendCommand(ControlCommand command) async {
    // 如果当前已有正在进行的命令
    if (_pendingResponse != null && !_pendingResponse!.isCompleted) {
      _pendingResponse!.completeError(
        Exception('Command cancelled by new request'),
      );
    }

    _pendingResponse = Completer<ControlResponse>();

    try {
      final bytes = command.toBytes();
      developer.log(
        "[$_tag] Sending command: ${command.opCode.name}",
        name: _tag,
      );

      // 发送命令
      await _device.writeCharacteristic(
        FtmsConstants.serviceUuid,
        FtmsConstants.fitnessMachineControlPointUuid,
        bytes,
        withResponse: true,
      );

      // 等待响应，并设置超时保护
      return await _pendingResponse!.future.timeout(
        _commandTimeout,
        onTimeout: () {
          developer.log(
            "[$_tag] Command timeout: ${command.opCode.name}",
            name: _tag,
          );
          return ControlResponse(
            requestOpCode: command.opCode,
            resultCode: ControlResultCode.operationFailed,
          );
        },
      );
    } catch (e) {
      return ControlResponse(
        requestOpCode: command.opCode,
        resultCode: ControlResultCode.operationFailed,
      );
    } finally {
      _pendingResponse = null;
    }
  }

  /// 请求控制设备。
  Future<ControlResponse> requestControl() =>
      sendCommand(ControlCommand.requestControl());

  /// 重置设备。
  Future<ControlResponse> reset() => sendCommand(ControlCommand.reset());

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
  Future<ControlResponse> stop() => sendCommand(ControlCommand.stop());

  /// 暂停设备。
  Future<ControlResponse> pause() => sendCommand(ControlCommand.pause());
}
