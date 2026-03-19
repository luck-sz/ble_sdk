import 'dart:typed_data';
import '../../models/workout_data.dart';
import '../../models/machine_type.dart';
import 'characteristics/treadmill_data.dart';
import 'characteristics/cross_trainer_data.dart';
import 'characteristics/rower_data.dart';
import 'characteristics/indoor_bike_data.dart';
import 'ftms_constants.dart';

/// 统一的 FTMS 数据解析器。
///
/// 根据特性 UUID 将原始特性数据路由到对应的解析器进行处理。
class FtmsDataParser {
  FtmsDataParser._();

  /// 根据给定的特性 UUID 和原始数据解析运动数据。
  static WorkoutData? parseWorkoutData(
    String characteristicUuid,
    Uint8List data, {
    MachineType? machineType,
  }) {
    final uuid = characteristicUuid.toLowerCase();

    if (uuid == FtmsConstants.treadmillDataUuid) {
      return TreadmillDataParser.parse(data, machineType: machineType);
    } else if (uuid == FtmsConstants.crossTrainerDataUuid) {
      return CrossTrainerDataParser.parse(data, machineType: machineType);
    } else if (uuid == FtmsConstants.rowerDataUuid) {
      return RowerDataParser.parse(data, machineType: machineType);
    } else if (uuid == FtmsConstants.indoorBikeDataUuid) {
      return IndoorBikeDataParser.parse(data, machineType: machineType);
    }

    return null;
  }

  /// 根据设备类型获取对应的运动数据特性 UUID。
  static String? getDataCharacteristicUuid(MachineType machineType) {
    switch (machineType) {
      case MachineType.treadmill:
      case MachineType.walkingMachine:
        return FtmsConstants.treadmillDataUuid;
      case MachineType.crossTrainer:
        return FtmsConstants.crossTrainerDataUuid;
      case MachineType.rower:
        return FtmsConstants.rowerDataUuid;
      case MachineType.indoorBike:
        return FtmsConstants.indoorBikeDataUuid;
      default:
        return null;
    }
  }
}
