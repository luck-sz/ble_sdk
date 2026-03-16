import 'dart:math';
import 'dart:typed_data';

/// 伊启 ES 通讯握手协议经理类。
///
/// 负责实现文档 V1.0 中的 4 步握手逻辑：
/// 1. 发起对码请求 (OpCode 0x08, 0x01, RandomX)
/// 2. 解析控制器的 6 字节响应 (0x08, 0x04, C, D, E, F)
/// 3. 根据余数 (F % 6) 动态计算并回传校验数据 (G, H, I, J)
/// 4. 确认握手成功
class EsHandshakeManager {
  static const int opCodeHandshake = 0x08;
  static const int actionRequest = 0x01;
  static const int actionResponse = 0x04;
  static const int failSignal = 0xFF;

  final Random _random = Random();

  /// 生成步骤 1 的对码请求包 (3 字节)。
  ///
  /// 返回格式：[0x08, 0x01, 随机数X]
  Uint8List generatePairingRequest() {
    final int x = _random.nextInt(256);
    return Uint8List.fromList([opCodeHandshake, actionRequest, x]);
  }

  /// 处理步骤 2 中控制器的响应，并生成步骤 3 需回传的校验包。
  ///
  /// [controllerData] 应该是去掉协议头后的数据，即 [0x08, 0x04, C, D, E, F]
  Uint8List? handleControllerResponse(Uint8List controllerData) {
    if (controllerData.length < 6) return null;
    if (controllerData[0] != opCodeHandshake ||
        controllerData[1] != actionResponse) {
      return null;
    }

    // 步骤 3 逻辑：使用最后一个数 F 除以 6 取余数获得模式序号
    final int f = controllerData[5];
    final int patternIndex = f % 6;

    // 生成新的随机数 A 和 B 用于回传校验
    final int a = _random.nextInt(100);
    final int b = _random.nextInt(100);

    // 根据模式序号生成 G, H, I, J
    final passwordGroup = _generatePasswordGroupByPattern(patternIndex, a, b);

    // 构建回传包：0x08, 0x04, G, H, I, J
    final result = Uint8List(6);
    result[0] = opCodeHandshake;
    result[1] = actionResponse;
    result.setRange(2, 6, passwordGroup);

    return result;
  }

  /// 根据文档中的 6 种模式算法生成密码组。
  List<int> _generatePasswordGroupByPattern(int index, int a, int b) {
    final int sum = (a + b) & 0xFF;
    final int mul = (a * b) & 0xFF;

    switch (index) {
      case 0: // 0: A, B, A+B, A*B
        return [a, b, sum, mul];
      case 1: // 1: A, B, A*B, A+B
        return [a, b, mul, sum];
      case 2: // 2: A+B, A, B, A*B
        return [sum, a, b, mul];
      case 3: // 3: A*B, A, B, A+B
        return [mul, a, b, sum];
      case 4: // 4: A+B, A*B, A, B
        return [sum, mul, a, b];
      case 5: // 5: A*B, A+B, A, B
        return [mul, sum, a, b];
      default:
        return [a, b, sum, mul];
    }
  }

  /// 校验控制器返回的数据是否符合预期的模式 (用于 APP 端的自我审计)。
  bool verifyControllerData(Uint8List data) {
    if (data.length < 6) return false;
    final int f = data[5];
    final int index = f % 6;

    final int c = data[2];
    final int d = data[3];
    final int e = data[4];
    final int fVal = data[5];

    // 这里根据 index 反推 C, D, E 是否符合加法/乘法逻辑
    // 这是一个可选的安全性增强步骤
    try {
      switch (index) {
        case 0:
          return (c + d) & 0xFF == e && (c * d) & 0xFF == fVal;
        case 1:
          return (c * d) & 0xFF == e && (c + d) & 0xFF == fVal;
        case 2:
          return (d + e) & 0xFF == c && (d * e) & 0xFF == fVal;
        case 3:
          return (d * e) & 0xFF == c && (d + e) & 0xFF == fVal;
        case 4:
          return (e + fVal) & 0xFF == c && (e * fVal) & 0xFF == d;
        case 5:
          return (e * fVal) & 0xFF == c && (e + fVal) & 0xFF == d;
      }
    } catch (_) {
      return false;
    }
    return true;
  }
}
