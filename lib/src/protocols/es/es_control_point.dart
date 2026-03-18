import 'dart:typed_data';
import 'dart:developer' as developer;
import '../../core/ble_device.dart';
import '../../core/byte_utils.dart';
import '../../models/control_command.dart';
import 'es_constants.dart';

class EsControlPoint {
  static const String _tag = 'BleSdk:EsControlPoint';
  /// 生成一个基础的数据包
  static Uint8List buildPacket(int opCode, List<int> payload) {
    int length = payload.length;
    // Packet Structure: Header(0xA9), OpCode, Length, Payload..., Checksum
    List<int> bytes = [EsConstants.header, opCode, length];
    bytes.addAll(payload);

    // 计算异或校验和
    int checksum = 0;
    for (int b in bytes) {
      checksum ^= b;
    }
    bytes.add(checksum);

    final res = Uint8List.fromList(bytes);
    developer.log(
      '[EsControlPoint] DEBUG SEND HEX: ${bytes.map((e) => e.toRadixString(16).padLeft(2, "0").toUpperCase()).join(" ")}',
      name: _tag,
    );
    return res;
  }

  /// 发送指令给设备
  static Future<ControlResponse> sendCommand(
      BleDevice device, ControlCommand command) async {
    try {
      Uint8List? payload;

      switch (command.opCode) {
        case ControlOpCode.startOrResume:
          payload = buildPacket(EsConstants.cmdControl, [EsConstants.controlStart]);
          break;
        case ControlOpCode.stopOrPause:
          if (command.parameter != null && command.parameter!.isNotEmpty) {
            final param = command.parameter![0];
            if (param == StopPauseParam.stop.code) {
              payload = buildPacket(EsConstants.cmdControl, [EsConstants.controlStop]);
            } else if (param == StopPauseParam.pause.code) {
              payload = buildPacket(EsConstants.cmdControl, [EsConstants.controlPause]);
            }
          }
          break;
        case ControlOpCode.setTargetSpeed:
          if (command.parameter != null && command.parameter!.length >= 2) {
            // ControlCommand speedKmh is saved as speedKmh * 100 in uint16
            int speedTimes100 = ByteUtils.readUint16(command.parameter!, 0);
            // ES Protocol speed is speedKmh * 10, thus divide by 10
            int targetSpeed = (speedTimes100 / 10).round();
            payload = buildPacket(EsConstants.cmdSetSpeed, [targetSpeed]);
          }
          break;
        case ControlOpCode.setTargetInclination:
          if (command.parameter != null && command.parameter!.length >= 2) {
            // ControlCommand inclination is saved as inclinationPercent * 10 in sint16
            int inclTimes10 = ByteUtils.readSint16(command.parameter!, 0);
            // ES Protocol incline is integer unit 1.0 (e.g. 5% incline = 5)
            int targetIncline = (inclTimes10 / 10).round();
            payload = buildPacket(EsConstants.cmdSetIncline, [targetIncline]);
          }
          break;
        case ControlOpCode.requestControl:
          // 对于 ES 协议，控制权的获取是隐含在 0x08 握手中的。
          // 当我们在 Demo 层调用 requestControl 时，如果已经握手成功，直接返回成功。
          // 这里发送 A0 同步包作为激活指令。
          payload = buildPacket(EsConstants.cmdStatusSync, [0, 0, 0]);
          break;
        // 扩展其它...
        default:
          return ControlResponse(
              requestOpCode: command.opCode,
              resultCode: ControlResultCode.opCodeNotSupported);
      }

      if (payload != null) {
        await device.writeCharacteristic(
          EsConstants.serviceUuid,
          EsConstants.writeUuid,
          payload,
          withResponse: false, // ES 使用 write without response
        );
        return ControlResponse(
            requestOpCode: command.opCode,
            resultCode: ControlResultCode.success);
      }
      return ControlResponse(
          requestOpCode: command.opCode,
          resultCode: ControlResultCode.opCodeNotSupported);
    } catch (e) {
      developer.log('[EsControlPoint] Error sending command ${command.opCode}: $e', name: _tag);
      return ControlResponse(
          requestOpCode: command.opCode,
          resultCode: ControlResultCode.operationFailed);
    }
  }

  /// 定时发送心跳保持连接/设备面板同步 (A0)
  static Future<void> syncStatus(BleDevice device, int status, double speed, double incline) async {
    int spdDeci = (speed * 10).round();
    int inclRaw = incline.round();
    
    Uint8List payload = buildPacket(EsConstants.cmdStatusSync, [status, spdDeci, inclRaw]);
    await device.writeCharacteristic(
      EsConstants.serviceUuid,
      EsConstants.writeUuid,
      payload,
      withResponse: false,
    );
  }
}
