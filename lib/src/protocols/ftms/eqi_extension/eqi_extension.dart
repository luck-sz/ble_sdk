import 'dart:async';
import 'dart:typed_data';

import '../../../core/ble_device.dart';
import '../ftms_constants.dart';
import 'unit_setting.dart';
import 'sport_id.dart';
import 'error_code.dart';
import 'mode_state.dart';
import 'buzzer_switch.dart';

/// EQI 私有扩展特性的管理器。
///
/// 这些是超出标准 FTMS 规范的自定义特性，
/// 专属于 EQI 健身设备。
class EqiExtensionManager {
  final BleDevice _device;

  final StreamController<EqiErrorCode> _errorCodeController =
      StreamController<EqiErrorCode>.broadcast();
  final StreamController<EqiModeState> _modeStateController =
      StreamController<EqiModeState>.broadcast();
  final StreamController<EqiBuzzerSwitch> _buzzerController =
      StreamController<EqiBuzzerSwitch>.broadcast();
  final StreamController<EqiUnitSetting> _unitController =
      StreamController<EqiUnitSetting>.broadcast();

  StreamSubscription? _errorCodeSub;
  StreamSubscription? _modeStateSub;
  StreamSubscription? _buzzerSub;
  StreamSubscription? _unitSub;

  EqiExtensionManager(this._device);

  /// 错误码通知的数据流。
  Stream<EqiErrorCode> get errorCodeStream => _errorCodeController.stream;

  /// 模式状态变化的数据流。
  Stream<EqiModeState> get modeStateStream => _modeStateController.stream;

  /// 蜂鸣器开关变化的数据流。
  Stream<EqiBuzzerSwitch> get buzzerSwitchStream => _buzzerController.stream;

  /// 单位设置变化的数据流。
  Stream<EqiUnitSetting> get unitSettingStream => _unitController.stream;

  /// 初始化并订阅 EQI 扩展特性的通知。
  Future<void> initialize() async {
    // 订阅错误码通知
    try {
      _errorCodeSub = _device
          .subscribeToCharacteristic(
            FtmsConstants.serviceUuid,
            EqiErrorCode.uuid,
          )
          .listen((data) {
            if (data.isNotEmpty) {
              _errorCodeController.add(EqiErrorCode.fromCode(data[0]));
            }
          }, onError: (_) {});
    } catch (_) {}

    // 订阅模式状态通知
    try {
      _modeStateSub = _device
          .subscribeToCharacteristic(
            FtmsConstants.serviceUuid,
            EqiModeState.uuid,
          )
          .listen((data) {
            _modeStateController.add(EqiModeState.fromBytes(data));
          }, onError: (_) {});
    } catch (_) {}

    // 订阅蜂鸣器开关通知
    try {
      _buzzerSub = _device
          .subscribeToCharacteristic(
            FtmsConstants.serviceUuid,
            EqiBuzzerSwitch.uuid,
          )
          .listen((data) {
            if (data.isNotEmpty) {
              _buzzerController.add(EqiBuzzerSwitch.fromByte(data[0]));
            }
          }, onError: (_) {});
    } catch (_) {}

    // 订阅单位设置通知
    try {
      _unitSub = _device
          .subscribeToCharacteristic(
            FtmsConstants.serviceUuid,
            EqiUnitSetting.uuid,
          )
          .listen((data) {
            if (data.isNotEmpty) {
              _unitController.add(EqiUnitSetting.fromByte(data[0]));
            }
          }, onError: (_) {});
    } catch (_) {}
  }

  // === 读取方法 ===

  /// 读取当前单位设置。
  Future<EqiUnitSetting> readUnitSetting() async {
    final data = await _device.readCharacteristic(
      FtmsConstants.serviceUuid,
      EqiUnitSetting.uuid,
    );
    return EqiUnitSetting.fromByte(data.isNotEmpty ? data[0] : 0);
  }

  /// 读取当前运动会话的运动 ID。
  Future<EqiSportId> readSportId() async {
    final data = await _device.readCharacteristic(
      FtmsConstants.serviceUuid,
      EqiSportId.uuid,
    );
    return EqiSportId.fromBytes(data);
  }

  /// 读取当前错误码。
  Future<EqiErrorCode> readErrorCode() async {
    final data = await _device.readCharacteristic(
      FtmsConstants.serviceUuid,
      EqiErrorCode.uuid,
    );
    return EqiErrorCode.fromCode(data.isNotEmpty ? data[0] : 0);
  }

  /// 读取当前模式状态。
  Future<EqiModeState> readModeState() async {
    final data = await _device.readCharacteristic(
      FtmsConstants.serviceUuid,
      EqiModeState.uuid,
    );
    return EqiModeState.fromBytes(data);
  }

  /// 读取蜂鸣器开关状态。
  Future<EqiBuzzerSwitch> readBuzzerSwitch() async {
    final data = await _device.readCharacteristic(
      FtmsConstants.serviceUuid,
      EqiBuzzerSwitch.uuid,
    );
    return EqiBuzzerSwitch.fromByte(data.isNotEmpty ? data[0] : 0);
  }

  // === 写入方法 ===

  /// 设置单位制（公制或英制）。
  Future<void> setUnitSetting(UnitSystem unit) async {
    await _device.writeCharacteristic(
      FtmsConstants.serviceUuid,
      EqiUnitSetting.uuid,
      Uint8List.fromList([unit.code]),
    );
  }

  /// 设置运动模式和目标值。
  Future<void> setModeState(EqiModeState modeState) async {
    await _device.writeCharacteristic(
      FtmsConstants.serviceUuid,
      EqiModeState.uuid,
      modeState.toBytes(),
    );
  }

  /// 设置蜂鸣器开关状态。
  Future<void> setBuzzerSwitch(bool enabled) async {
    await _device.writeCharacteristic(
      FtmsConstants.serviceUuid,
      EqiBuzzerSwitch.uuid,
      Uint8List.fromList([enabled ? 1 : 0]),
    );
  }

  /// 释放所有订阅和数据流。
  Future<void> dispose() async {
    await _errorCodeSub?.cancel();
    await _modeStateSub?.cancel();
    await _buzzerSub?.cancel();
    await _unitSub?.cancel();
    await _errorCodeController.close();
    await _modeStateController.close();
    await _buzzerController.close();
    await _unitController.close();
  }
}
