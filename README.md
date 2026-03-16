# EQI BLE SDK 使用指南

EQI BLE SDK 是一个专为全系列健身设备（跑步机、单车、椭圆机等）设计的 Flutter 插件。它封装了标准的 FTMS 协议，并支持 EQI 私有的扩展协议（ES、EFC 等）。

## 1. 安装与配置

### 1.1 依赖引用
在您的 Flutter 项目的 `pubspec.yaml` 中，通过本地路径引用该 SDK：

```yaml
dependencies:
  eqi_ble_sdk:
    path: ../eqi_ble_sdk # 请填写 SDK 在您电脑上的真实相对或绝对路径
```

### 1.2 权限配置
由于 SDK 基于 `flutter_blue_plus`，请确保您的项目已配置蓝牙相关权限。

**Android:**
在 `AndroidManifest.xml` 中添加：
```xml
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

**iOS:**
在 `Info.plist` 中添加：
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>我们需要蓝牙连接健身设备</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>我们需要蓝牙连接健身设备</string>
```

---

## 2. 快速入门

### 2.1 扫描并识别设备
您可以使用 SDK 提供的 `ProtocolRegistry` 自动识别扫描到的蓝牙设备是否支持 EQI 协议。

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:eqi_ble_sdk/eqi_ble_sdk.dart';

// 监听扫描结果
FlutterBluePlus.onScanResults.listen((results) {
  for (ScanResult r in results) {
    // 1. 将原生的广播数据包装为 SDK 模型
    final adData = AdvertisingData.fromScanResult(r);
    
    // 2. 使用协议注册表进行匹配
    final protocol = ProtocolRegistry.getProtocolForDevice(adData);
    
    if (protocol != null) {
      print("发现设备: ${r.device.platformName}, 匹配协议: ${protocol.protocolName}");
      // 进行下一步连接...
    }
  }
});
```

### 2.2 连接与协议初始化
连接设备时，请使用 `FbpBleDevice` 驱动包装类。

```dart
// 1. 创建驱动
final bleDevice = FbpBleDevice(nativeBluetoothDevice);

// 2. 连接并请求 MTU (SDK 内部已封装好相关逻辑)
await bleDevice.connect();

// 3. 获取对应的协议处理器 (例如 FTMS)
final ftms = FtmsProtocol();
await ftms.initialize(bleDevice);

print("协议初始化成功，正在监听数据...");
```

---

## 3. 核心功能调用

### 3.1 监听运动数据
SDK 将原始的蓝牙字节数据解析为统一的 `WorkoutData` 模型。

```dart
ftms.workoutDataStream.listen((data) {
  print("--- 实时数据 ---");
  print("速度: ${data.speed} km/h");
  print("坡度: ${data.inclination} %");
  print("距离: ${data.distance} m");
  print("热量: ${data.calories} kcal");
  print("心率: ${data.heartRate} bpm");
});
```

### 3.2 发送控制命令
**重要：** FTMS 协议规定，在发送设置命令前，通常必须先调用 `requestControl()`。

```dart
// 1. 请求控制权
final resControl = await ftms.sendCommand(ControlCommand.requestControl());

if (resControl.isSuccess) {
  // 2. 开始运动
  await ftms.sendCommand(ControlCommand.startOrResume());
  
  // 3. 设置目标速度 (例如 5.0 km/h)
  await ftms.sendCommand(ControlCommand.setTargetSpeed(5.0));
  
  // 4. 停止运动
  // await ftms.sendCommand(ControlCommand.stop());
}
```

### 3.3 EQI 特有扩展功能
针对支持 EQI 扩展特性的设备，可以使用 `eqiExtension` 接口：

```dart
// 切换单位为公制 (Metric)
await ftms.eqiExtension.setUnit(UnitType.metric);

// 控制蜂鸣器开关
await ftms.eqiExtension.setBuzzer(true);
```

---

## 4. 调试说明
本 SDK 在关键路径上埋入了日志，前缀标识为 `[BleSdk]`。

您可以在调试控制台搜索 `BleSdk` 来查看完整的通信流程，包括：
*   连接状态变更。
*   MTU 请求结果。
*   命令发送与设备返回的确认结果。
*   协议解析异常。

---

## 5. 常见问题 (FAQ)

**Q: 发送命令后没有效果？**
A: 请检查是否先成功调用了 `requestControl()`。另外，请在 `BleSdk` 日志中确认设备返回的 `ControlResponse` 是否为 `success`。

**Q: 连接成功但收不到数据？**
A: 请确认 `ftms.initialize(device)` 是否已执行完成。该步骤会订阅所有相关的蓝牙通知 (Notify)。
