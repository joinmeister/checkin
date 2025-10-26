// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      isDirectPrintingEnabled: fields[0] as bool,
      printTimeoutSeconds: fields[1] as int,
      defaultPrinter: fields[2] as String?,
      enableHapticFeedback: fields[3] as bool,
      enableSoundEffects: fields[4] as bool,
      enableOfflineMode: fields[5] as bool,
      lastSyncTime: fields[6] as DateTime?,
      selectedEventId: fields[7] as String?,
      selectedTabIndex: fields[8] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.isDirectPrintingEnabled)
      ..writeByte(1)
      ..write(obj.printTimeoutSeconds)
      ..writeByte(2)
      ..write(obj.defaultPrinter)
      ..writeByte(3)
      ..write(obj.enableHapticFeedback)
      ..writeByte(4)
      ..write(obj.enableSoundEffects)
      ..writeByte(5)
      ..write(obj.enableOfflineMode)
      ..writeByte(6)
      ..write(obj.lastSyncTime)
      ..writeByte(7)
      ..write(obj.selectedEventId)
      ..writeByte(8)
      ..write(obj.selectedTabIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
