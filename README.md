# EQI BLE SDK

EQI BLE SDK 是一个专为 **EQI (亿健)** 健身设备设计的 Flutter SDK。它封装了标准 FTMS 协议以及 EQI 私有的扩展协议，采用协议无关的可伸缩架构，能够轻松适配各种底层的蓝牙库（如 `flutter_blue_plus`、`flutter_reactive_ble` 等）。

## 核心特性

- **协议无关架构**：解耦了底层蓝牙库与业务代码，通过实现 `BleDevice` 接口即可替换蓝牙驱动。
- **全机型支持**：内置 FTMS 标准下的跑步机、走步机、椭圆机、划船机、室内单车数据解析。
- **EQI 私有扩展**：支持蜂鸣器开关、运动模式设定、目标值设定、故障码读取及运动会话 ID 管理。
- **统一数据模型**：无论何种设备，均输出一致的 `WorkoutData`、`MachineStatus` 和 `TrainingStatus`。
- **类型安全**：采用位段级解析，确保数据的准确性与高效性。

## 项目结构

```text
lib/
├── eqi_ble_sdk.dart         # SDK 总入口，导出所有接口
└── src/
    ├── core/                # 核心层：定义 BleDevice, BleProtocol 等抽象接口
    ├── models/              # 模型层：定义 WorkoutData, MachineType 等通用模型
    ├── protocols/           # 协议实现层
    │   └── ftms/            # FTMS 协议及其 EQI 扩展实现
    │       ├── characteristics/ # 各机型数据特有的解析器
    │       └── eqi_extension/   # EQI 私有扩展特性管理
    └── protocol_registry.dart # (待实现) 协议注册中心，用于自动识别协议
```

## 使用说明

### 1. 实现 BleDevice 驱动

由于本 SDK 是抽象的，你需要使用你喜欢的蓝牙库实现 `BleDevice` 接口：

```dart
class MyBleDevice extends BleDevice {
  // 实现 connect, disconnect, discoverServices, 
  // writeCharacteristic, subscribeToCharacteristic 等方法
}
```

### 2. 初始化协议

使用实现的 `BleDevice` 实例初始化对应的协议（以 FTMS 为例）：

```dart
final device = MyBleDevice(id: "XX:XX:XX:XX");
final protocol = FtmsProtocol(); // 实例化 FTMS 协议

await protocol.initialize(device);
```

### 3. 监听运动数据

```dart
protocol.workoutDataStream.listen((data) {
  print("当前速度: ${data.instantaneousSpeed} km/h");
  print("累计距离: ${data.totalDistance} m");
});

protocol.machineStatusStream.listen((status) {
  if (status.isStopped) print("设备已停止");
});
```

### 4. 发送控制命令

```dart
// 请求控制权
await protocol.sendCommand(ControlCommand.requestControl());

// 启动设备
await protocol.sendCommand(ControlCommand.startOrResume());

// 设置速度
await protocol.sendCommand(ControlCommand.setTargetSpeed(8.5));
```

### 5. 使用 EQI 扩展功能

```dart
final ftms = protocol as FtmsProtocol;
final extension = ftms.eqiExtension;

// 设置目标运动时间（600秒）
await extension.setModeState(EqiModeState(
  supportedModes: 0x0F, 
  currentMode: EqiWorkoutMode.time,
  modeTarget: 600,
));

// 关闭蜂鸣器
await extension.setBuzzerSwitch(false);
```

## 缺失项分析

目前项目已搭建了稳健的基础架构，但仍缺失以下关键组件：

1.  **`FtmsProtocol` 类实现**：`lib/src/protocols/ftms/ftms_protocol.dart` 尚未创建，它是连接 `BleDevice` 与各项解析器的中枢。
2.  **`ProtocolRegistry` 类实现**：`lib/src/protocol_registry.dart` 尚未创建，用于根据广播信息自动匹配设备协议。
3.  **单元测试**：目前 `test/` 目录下缺乏针对各种数据解析器的 Mock 测试。
4.  **示例工程**：`example/` 文件夹缺失，建议提供一个完整的 `flutter_blue_plus` 适配示例。
5.  **依赖配置**：`pubspec.yaml` 中尚未添加可能需要的辅助库（如 `meta` 用于注解）。

---
© 2026 EQI Team. All rights reserved.
