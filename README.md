# BLE SDK 使用指南

BLE SDK 是一个专为全系列健身设备（跑步机、单车、椭圆机、划船机等）设计的 Flutter 插件。它通过统一的抽象接口，封装了标准的 **FTMS** 协议，并深度兼容支持 EQI 私有的扩展协议（**ES**, **EFC** 等）。

---

## 1. 安装与配置

### 1.1 依赖引用
在您的 Flutter 项目的 `pubspec.yaml` 中，通过本地路径引用该 SDK：

```yaml
dependencies:
  ble_sdk:
    path: ../ble_sdk # 请填写 SDK 在您电脑上的真实相对或绝对路径
```

### 1.2 权限配置
由于 SDK 基于 `flutter_blue_plus`，请确保您的项目已手动配置所需的蓝牙动态权限。

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

### 2.1 扫描周边设备（启发式匹配）
扫描时，SDK 提供的 `ProtocolRegistry` 能够根据系统的广播数据初步预测该设备支持的通信协议：

```dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_sdk/ble_sdk.dart';

FlutterBluePlus.onScanResults.listen((results) {
  for (ScanResult r in results) {
    // 1. 包装广播数据
    final adData = AdvertisingData.fromScanResult(r);
    
    // 2. 根据广播快速预测协议实例（注意：广播包可能会残缺，此非 100% 准确）
    final protocol = ProtocolRegistry.getProtocolForDevice(adData);
    
    if (protocol != null) {
      print("发现设备: ${r.device.platformName}, 预测协议: ${protocol.protocolName}");
      // 可以在列表中展示该设备供用户点击连接
    }
  }
});
```

### 2.2 连接与精确协议识别
建立底部物理连接后，**强烈建议**再次使用 `ProtocolRegistry.resolveProtocolAsync` 确认准确协议版本，不要硬编码 `FtmsProtocol`。

```dart
// 1. 包装成 SDK 驱动实例
final bleDevice = FbpBleDevice(nativeBluetoothDevice);

// 2. 建立系统蓝牙连接 (内部已包含请求 MTU 等操作)
await bleDevice.connect();

// 3. 【推荐】扫描具体蓝牙服务（Services & Characteristics）进行 100% 精准的协议匹配
BleProtocol? protocol = await ProtocolRegistry.resolveProtocolAsync(bleDevice);

if (protocol == null) {
    print("该设备不支持被识别的数据协议。");
    await bleDevice.disconnect();
    return;
}

// 4. 执行初始化 (订阅特征、完成特定协议握手)
print("正在初始化 ${protocol.protocolName} ...");
await protocol.initialize(bleDevice);
print("初始化完成，现可正常通信！");
```

---

## 3. 核心功能使用

### 3.1 监听运动数据与设备状态
SDK 已经将底层的 FTMS、ES 等杂乱协议统一解析成了通用的 `WorkoutData` 和 `MachineStatus` 模型。

```dart
// 实时运动数据
protocol.workoutDataStream.listen((data) {
  print("--- 实时数据 ---");
  print("速度: ${data.instantaneousSpeed} km/h");
  print("坡度: ${data.inclination}");
  print("距离: ${data.totalDistance} m");
  print("热量: ${data.totalEnergy} kcal");
  print("心率: ${data.heartRate} bpm");
});

// 设备状态变化 (如：开始、停止、安全锁脱落等)
protocol.machineStatusStream.listen((status) {
    print("设备状态变更: ${status.statusCode}");
});
```

### 3.2 发送控制命令
**重要：** 大部分协议（尤其是标准 FTMS）规定，设置设备速度或要求其开始运转之前，必须先请求**控制权**！

```dart
// 1. 请求控制权
final resControl = await protocol.sendCommand(ControlCommand.requestControl());

if (resControl.isSuccess) {
  // 2. 下发开始运动指令
  await protocol.sendCommand(ControlCommand.startOrResume());
  
  // 3. 修改目标速度 (例如设定 5.0 km/h)
  await protocol.sendCommand(ControlCommand.setTargetSpeed(5.0));
  
  // 4. 下发停止指令
  // await protocol.sendCommand(ControlCommand.stopOrPause(StopPauseParam.stop));
}
```

### 3.3 FTMS 特有 EQI 扩展命令
部分设置（如公英制切换、蜂鸣器控制）是附加在 FTMS 协议之上的一层扩展，需向下转型至 `FtmsProtocol` 才可使用：

```dart
if (protocol is FtmsProtocol) {
  // 切换单位为公制 (Metric)
  await protocol.eqiExtension.setUnit(UnitType.metric);

  // 控制面板蜂鸣器响铃
  await protocol.eqiExtension.setBuzzer(true);
}
```

### 3.4 资源释放管理
当用户断开设备或者离开运动页面时，必须销毁协议并切断连接，特别是 **ES 协议**内部有心跳定时器，如果不销毁会造成内存异常。

```dart
// 销毁 Stream 控制器及心跳 Timer
await protocol?.dispose(); 

// 切断物理外设连接
await bleDevice.disconnect();
```

---

## 4. 调试说明
本 SDK 在关键的指令收发、协议握手处埋入了详细日志，前缀为 `[BleSdk]`。

您可在 Flutter 的调试控制台输入过滤条件 `BleSdk` 来查看：
* 连接阶段的 MTU 大小变化。
* 服务解析阶段的匹配情况 (`resolveProtocolAsync`)。
* ES 私有协议复杂的 3 步骤安全握手过程。
* 指令发送后设备主板返回的 `ControlResponse` 的原始 Payload 和成功状态。

---

## 5. 常见问题 (FAQ)

**Q: 为什么获取到目标设备但是发送命令后主控没有任何响应？**
A: 请确保您成功下发了 `ControlCommand.requestControl()` 并收到了 `isSuccess == true`。否则任何 Start、Target Speed 指令设备主控皆不予处理。

**Q: ES协议设备（例如旧款跑步机）调用 `initialize(bleDevice)` 时为什么卡顿了好几秒？**
A: 这是正常现象。因为旧款 ES 设备的底层设计有防串联安全机制，SDK 必须在几秒钟内与其隐式完成【建立暗号 - 验证暗号 - 获取许可心跳】这三个握手阶段。所以必须 `await` 其就绪后再显示可操作面板。

**Q: 连接成功但控制台报错 `No matching protocol found`，数据收不到怎么回事？**
A: 原因是设备虽配对了蓝牙，但这台设备的主控软硬件可能不包含对应 `0x1826 (FTMS)`、`0xFFF0 (ES)` 等特定的 Service UUID。该设备极可能不是运动健身器材，或者该型号本身未导入兼容功能。
