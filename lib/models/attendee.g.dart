// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendee.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendeeAdapter extends TypeAdapter<Attendee> {
  @override
  final int typeId = 1;

  @override
  Attendee read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attendee(
      id: fields[0] as String,
      eventId: fields[1] as String,
      eventbriteId: fields[2] as String?,
      firstName: fields[3] as String,
      lastName: fields[4] as String,
      email: fields[5] as String,
      ticketType: fields[6] as String,
      ticketPrice: fields[7] as double?,
      isVip: fields[8] as bool,
      isCheckedIn: fields[9] as bool,
      checkedInAt: fields[10] as DateTime?,
      qrCode: fields[11] as String,
      badgeGenerated: fields[12] as bool,
      vipLogoUrl: fields[13] as String?,
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Attendee obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.eventId)
      ..writeByte(2)
      ..write(obj.eventbriteId)
      ..writeByte(3)
      ..write(obj.firstName)
      ..writeByte(4)
      ..write(obj.lastName)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.ticketType)
      ..writeByte(7)
      ..write(obj.ticketPrice)
      ..writeByte(8)
      ..write(obj.isVip)
      ..writeByte(9)
      ..write(obj.isCheckedIn)
      ..writeByte(10)
      ..write(obj.checkedInAt)
      ..writeByte(11)
      ..write(obj.qrCode)
      ..writeByte(12)
      ..write(obj.badgeGenerated)
      ..writeByte(13)
      ..write(obj.vipLogoUrl)
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
      other is AttendeeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
