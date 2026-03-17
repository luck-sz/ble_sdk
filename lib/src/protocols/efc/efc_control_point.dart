import 'dart:typed_data';
import 'dart:developer' as developer;

import '../../core/ble_device.dart';
import '../../models/control_command.dart';
import 'efc_constants.dart';

class EfcControlPoint {
  static const String _tag = "EfcControlPoint";
  final BleDevice _device;

  EfcControlPoint(this._device);

  /// 根据 EFC 协议格式构造控制指令字节流
  Uint8List buildCommand(int cmd, Uint8List data) {
    int len = data.length;
    List<int> packet = [EfcConstants.headerTx, cmd, len];
    packet.addAll(data);

    // 计算 Checksum (XOR)
    int checksum = 0;
    for (int b in packet) {
      checksum ^= b;
    }
    packet.add(checksum);

    return Uint8List.fromList(packet);
  }

  /// 将标准 FTMS 控制指令映射为 EFC 协议指令，并发送。
  Future<ControlResponse> sendCommand(ControlCommand command) async {
    developer.log("[$_tag] Sending command: $command", name: _tag);

    int efcCmd = 0;
    List<int> efcData = [];

    switch (command.opCode) {
      case ControlOpCode.startOrResume:
        efcCmd = EfcConstants.cmdStatusControl;
        efcData = [EfcConstants.statusStart];
        break;
      case ControlOpCode.stopOrPause:
        efcCmd = EfcConstants.cmdStatusControl;
        if (command.parameter != null && command.parameter!.isNotEmpty) {
          int param = command.parameter![0];
          if (param == StopPauseParam.stop.code) {
            efcData = [EfcConstants.statusStop];
          } else if (param == StopPauseParam.pause.code) {
            efcData = [EfcConstants.statusPause];
          } else {
            efcData = [EfcConstants.statusStop]; // 默认停止
          }
        } else {
          efcData = [EfcConstants.statusStop];
        }
        break;
      case ControlOpCode.setTargetSpeed:
        efcCmd = EfcConstants.cmdSpeedControl;
        // 映射参数：Byte 0: 0x01(绝对调节), Byte 1: 速度值(单位: 0.1)
        if (command.parameter != null && command.parameter!.length >= 2) {
          // command.parameter 中的速度是 unit16(0.01km/h)
          int speed0_01 = (command.parameter![1] << 8) | command.parameter![0];
          int speed0_1 = (speed0_01 / 10).round();
          efcData = [0x01, speed0_1];
        }
        break;
      case ControlOpCode.setTargetInclination:
        efcCmd = EfcConstants.cmdInclineControl;
        // 映射参数：Byte 0: 0x01(绝对调节), Byte 1: 坡度值(1档)
        if (command.parameter != null && command.parameter!.length >= 2) {
          int inc0_1 = (command.parameter![1] << 8) | command.parameter![0];
          int inc1 = (inc0_1 / 10).round();
          efcData = [0x01, inc1];
        }
        break;
      case ControlOpCode.requestControl:
        // EFC 协议多数情况直接控制，无需 Request Control
        return const ControlResponse(
            requestOpCode: ControlOpCode.requestControl,
            resultCode: ControlResultCode.success);
      default:
        // 其他不支持的控制指令
        developer.log("[$_tag] Unsupported opCode for EFC: ${command.opCode}",
            name: _tag);
        return ControlResponse(
          requestOpCode: command.opCode,
          resultCode: ControlResultCode.opCodeNotSupported,
        );
    }

    // 构造最终的 EFC 包
    Uint8List packet = buildCommand(efcCmd, Uint8List.fromList(efcData));
    developer.log("[$_tag] EFC packet length: ${packet.length}, bytes: $packet", name: _tag);

    // 无响应写入 (Write Without Response 支持)
    try {
      await _device.writeCharacteristic(
        EfcConstants.serviceUuid,
        EfcConstants.writeUuid,
        packet,
        withResponse: false,
      );
      return ControlResponse(
        requestOpCode: command.opCode,
        resultCode: ControlResultCode.success,
      );
    } catch (e) {
      developer.log("[$_tag] Error sending EFC command: $e", name: _tag);
      return ControlResponse(
        requestOpCode: command.opCode,
        resultCode: ControlResultCode.operationFailed,
      );
    }
  }

  /// 处理从设备返回的响应数据（如果有的话）。
  /// 在 EFC 中，设备反馈不一定遵循 FTMS Request->Indication 模式。
  void handleControlPointResponse(Uint8List data) {
    if (data.length < 5 || data[0] != EfcConstants.headerRx) return;
    // ... 可能包含命令状态执行回调（如有）
  }
}
