// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Event(
      id: fields[0] as String,
      eventbriteId: fields[1] as String?,
      name: fields[2] as String,
      description: fields[3] as String,
      startDate: fields[4] as DateTime,
      endDate: fields[5] as DateTime,
      venue: fields[6] as String,
      status: fields[7] as String,
      calculatedStatus: fields[8] as String?,
      totalAttendees: fields[9] as int,
      checkedInCount: fields[10] as int,
      vipCount: fields[11] as int,
      regularBadgeTemplateId: fields[12] as String?,
      vipBadgeTemplateId: fields[13] as String?,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.eventbriteId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.startDate)
      ..writeByte(5)
      ..write(obj.endDate)
      ..writeByte(6)
      ..write(obj.venue)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.calculatedStatus)
      ..writeByte(9)
      ..write(obj.totalAttendees)
      ..writeByte(10)
      ..write(obj.checkedInCount)
      ..writeByte(11)
      ..write(obj.vipCount)
      ..writeByte(12)
      ..write(obj.regularBadgeTemplateId)
      ..writeByte(13)
      ..write(obj.vipBadgeTemplateId)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
