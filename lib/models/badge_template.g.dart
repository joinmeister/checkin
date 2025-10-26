// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'badge_template.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BadgeTemplateAdapter extends TypeAdapter<BadgeTemplate> {
  @override
  final int typeId = 3;

  @override
  BadgeTemplate read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BadgeTemplate(
      id: fields[0] as String,
      name: fields[1] as String,
      eventId: fields[2] as String,
      labelSizeId: fields[3] as String,
      isVipTemplate: fields[4] as bool,
      backgroundColor: fields[5] as String,
      backgroundImage: fields[6] as String?,
      backgroundSettings: (fields[7] as Map?)?.cast<String, dynamic>(),
      textColor: fields[8] as String,
      logoUrl: fields[9] as String?,
      fields: (fields[10] as List).cast<BadgeField>(),
      dimensions: (fields[11] as Map).cast<String, dynamic>(),
      isDefault: fields[12] as bool,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime,
      isActive: fields[15] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, BadgeTemplate obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.eventId)
      ..writeByte(3)
      ..write(obj.labelSizeId)
      ..writeByte(4)
      ..write(obj.isVipTemplate)
      ..writeByte(5)
      ..write(obj.backgroundColor)
      ..writeByte(6)
      ..write(obj.backgroundImage)
      ..writeByte(7)
      ..write(obj.backgroundSettings)
      ..writeByte(8)
      ..write(obj.textColor)
      ..writeByte(9)
      ..write(obj.logoUrl)
      ..writeByte(10)
      ..write(obj.fields)
      ..writeByte(11)
      ..write(obj.dimensions)
      ..writeByte(12)
      ..write(obj.isDefault)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeTemplateAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BadgeFieldAdapter extends TypeAdapter<BadgeField> {
  @override
  final int typeId = 4;

  @override
  BadgeField read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BadgeField(
      id: fields[0] as String,
      type: fields[1] as String,
      content: fields[2] as String?,
      position: (fields[3] as Map).cast<String, double>(),
      size: (fields[4] as Map).cast<String, double>(),
      style: (fields[5] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, BadgeField obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.position)
      ..writeByte(4)
      ..write(obj.size)
      ..writeByte(5)
      ..write(obj.style);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BadgeFieldAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
