/// 协议支持的健身设备类型。
enum MachineType {
  /// 跑步机（Treadmill）
  treadmill(1, 'Treadmill', '跑步机'),

  /// 走步机（Walking Machine）
  walkingMachine(1, 'Walking Machine', '走步机'),

  /// 椭圆机（Elliptical / Cross Trainer）
  crossTrainer(2, 'Cross Trainer', '椭圆机'),

  /// 划船机（Rowing Machine）
  rower(3, 'Rower', '划船机'),

  /// 智能单车（Indoor Bike / Spin Bike）
  indoorBike(4, 'Indoor Bike', '智能单车'),

  /// 力量器械（Strength Equipment）
  strength(5, 'Strength', '力量器械'),

  /// 未知类型
  unknown(0, 'Unknown', '未知');

  final int code;
  final String englishName;
  final String chineseName;

  const MachineType(this.code, this.englishName, this.chineseName);

  /// 根据广播数据中的代码获取设备类型。
  static MachineType fromCode(int code) {
    return MachineType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => MachineType.unknown,
    );
  }
}
