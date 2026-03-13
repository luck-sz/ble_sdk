/// EQI BLE SDK - 用于 EQI 健身设备 BLE 通信的 Flutter SDK
///
/// 本 SDK 支持 EQI FTMS 通信协议，并设计为可扩展架构，
/// 以便未来支持更多协议（EFC、ES 等）。
library eqi_ble_sdk;

// 核心层 - 基础抽象
export 'src/core/ble_protocol.dart';
export 'src/core/ble_device.dart';
export 'src/core/ble_characteristic.dart';
export 'src/core/ble_constants.dart';
export 'src/core/data_parser.dart';
export 'src/core/byte_utils.dart';

// 数据模型层 - 通用数据模型
export 'src/models/device_info.dart';
export 'src/models/machine_type.dart';
export 'src/models/workout_data.dart';
export 'src/models/control_command.dart';
export 'src/models/machine_status.dart';
export 'src/models/supported_ranges.dart';
export 'src/models/training_status.dart';
export 'src/models/advertising_data.dart';

// FTMS 协议层
export 'src/protocols/ftms/ftms_protocol.dart';
export 'src/protocols/ftms/ftms_constants.dart';
export 'src/protocols/ftms/ftms_control_point.dart';
export 'src/protocols/ftms/ftms_machine_feature.dart';
export 'src/protocols/ftms/ftms_data_parser.dart';
export 'src/protocols/ftms/characteristics/treadmill_data.dart';
export 'src/protocols/ftms/characteristics/cross_trainer_data.dart';
export 'src/protocols/ftms/characteristics/rower_data.dart';
export 'src/protocols/ftms/characteristics/indoor_bike_data.dart';

// FTMS - EQI 扩展特性
export 'src/protocols/ftms/eqi_extension/eqi_extension.dart';
export 'src/protocols/ftms/eqi_extension/unit_setting.dart';
export 'src/protocols/ftms/eqi_extension/sport_id.dart';
export 'src/protocols/ftms/eqi_extension/error_code.dart';
export 'src/protocols/ftms/eqi_extension/mode_state.dart';
export 'src/protocols/ftms/eqi_extension/buzzer_switch.dart';

// 协议注册表
export 'src/protocol_registry.dart';
