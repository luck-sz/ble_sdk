import 'dart:math';
import 'dart:typed_data';

/// 伊启 ES 通讯握手协议经理类。
///
/// 负责实现文档 V1.0 中的 4 步握手逻辑：
/// 1. 发起对码请求 (OpCode 0x08, SubOp 0x01, RandomX)
/// 2. 解析控制器的 6 字节响应 (0x08, SubOp 0x04, C, D, E, F) 并校验模式 (X % 6)
/// 3. 根据响应的最后一个字节 (F % 6) 动态计算并回传校验数据 (G, H, I, J)
/// 4. 确认握手成功（收心跳包 02）或失败 (接收到 08 01 FF)
class EsHandshakeManager {
  static const int opCodeHandshake = 0x08;
  static const int subOpRequest = 0x01;
  static const int subOpResponse = 0x04;
  static const int failSignal = 0xFF;

  final Random _random = Random();
  int? _lastSentX;
  int? get lastSentX => _lastSentX;

  /// 生成步骤 1 的对码请求包内部 Payload [0x08, 0x01, 随机数X]。
  Uint8List generatePairingRequest() {
    final int x = _random.nextInt(256);
    _lastSentX = x;
    return Uint8List.fromList([opCodeHandshake, subOpRequest, x]);
  }

  /// 校验步骤 2 中控制器的响应是否符合基于 X 的模式。
  /// [payload] 应该是 [0x08, 0x04, C, D, E, F]
  bool verifyConsoleResponse(Uint8List payload) {
    if (_lastSentX == null) return false;
    if (payload.length < 6) return false;
    if (payload[0] != opCodeHandshake || payload[1] != subOpResponse) return false;

    final int index = _lastSentX! % 6;
    return _verifyDataByPattern(index, payload.sublist(2, 6));
  }

  /// 处理步骤 2 的响应（在校验通过后），生成步骤 3 需回传的校验包内部 Payload。
  /// [payload] 为控制器发来的 [0x08, 0x04, C, D, E, F]
  Uint8List? generateValidationReply(Uint8List payload) {
    if (payload.length < 6) return null;
    
    // 步骤 3 逻辑：使用收到包的最后一个数 F 除以 6 取余数获得模式序号
    final int f = payload[5];
    final int patternIndex = f % 6;

    // 生成新的随机数 A 和 B 用于回传挑战，文档指 random number，通常为 1 字节范围
    final int a = _random.nextInt(256);
    final int b = _random.nextInt(256);

    // 根据模式序号生成 G, H, I, J
    final passwordGroup = _generatePasswordGroupByPattern(patternIndex, a, b);

    // 构建回传包 Body：0x08, 0x04, G, H, I, J
    final result = Uint8List(6);
    result[0] = opCodeHandshake;
    result[1] = subOpResponse;
    result.setRange(2, 6, passwordGroup);

    return result;
  }

  /// 根据文档中的 6 种模式算法生成密码组。
  /// P1, P2 为原始随机数，S = P1 + P2, M = P1 * P2
  List<int> _generatePasswordGroupByPattern(int index, int p1, int p2) {
    final int s = (p1 + p2) & 0xFF;
    final int m = (p1 * p2) & 0xFF;

    switch (index) {
      case 0: return [p1, p2, s, m];
      case 1: return [p1, p2, m, s];
      case 2: return [s, p1, p2, m];
      case 3: return [m, p1, p2, s];
      case 4: return [s, m, p1, p2];
      case 5: return [m, s, p1, p2];
      default: return [p1, p2, s, m];
    }
  }

  /// 校验 4 字节数据组是否符合指定的模式算法。
  bool _verifyDataByPattern(int index, Uint8List group) {
    if (group.length < 4) return false;
    final int b0 = group[0];
    final int b1 = group[1];
    final int b2 = group[2];
    final int b3 = group[3];

    try {
      switch (index) {
        case 0: // P1, P2, S, M
          return (b0 + b1) & 0xFF == b2 && (b0 * b1) & 0xFF == b3;
        case 1: // P1, P2, M, S
          return (b0 * b1) & 0xFF == b2 && (b0 + b1) & 0xFF == b3;
        case 2: // S, P1, P2, M
          return (b1 + b2) & 0xFF == b0 && (b1 * b2) & 0xFF == b3;
        case 3: // M, P1, P2, S
          return (b1 * b2) & 0xFF == b0 && (b1 + b2) & 0xFF == b3;
        case 4: // S, M, P1, P2
          return (b2 + b3) & 0xFF == b0 && (b2 * b3) & 0xFF == b1;
        case 5: // M, S, P1, P2
          return (b2 * b3) & 0xFF == b0 && (b2 + b3) & 0xFF == b1;
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
