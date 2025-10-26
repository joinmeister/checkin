// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brother_printer.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrotherPrinterAdapter extends TypeAdapter<BrotherPrinter> {
  @override
  final int typeId = 10;

  @override
  BrotherPrinter read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BrotherPrinter(
      id: fields[0] as String,
      name: fields[1] as String,
      model: fields[2] as String,
      connectionType: fields[3] as PrinterConnectionType,
      capabilities: fields[4] as PrinterCapabilities,
      isMfiCertified: fields[5] as bool,
      bluetoothAddress: fields[6] as String?,
      ipAddress: fields[7] as String?,
      status: fields[8] as PrinterStatus,
      lastSeen: fields[9] as DateTime,
      connectionData: (fields[10] as Map).cast<String, dynamic>(),
    );
  }

  @override
  void write(BinaryWriter writer, BrotherPrinter obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.model)
      ..writeByte(3)
      ..write(obj.connectionType)
      ..writeByte(4)
      ..write(obj.capabilities)
      ..writeByte(5)
      ..write(obj.isMfiCertified)
      ..writeByte(6)
      ..write(obj.bluetoothAddress)
      ..writeByte(7)
      ..write(obj.ipAddress)
      ..writeByte(8)
      ..write(obj.status)
      ..writeByte(9)
      ..write(obj.lastSeen)
      ..writeByte(10)
      ..write(obj.connectionData);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrotherPrinterAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrinterCapabilitiesAdapter extends TypeAdapter<PrinterCapabilities> {
  @override
  final int typeId = 11;

  @override
  PrinterCapabilities read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrinterCapabilities(
      supportedLabelSizes: (fields[0] as List).cast<LabelSize>(),
      maxResolutionDpi: fields[1] as int,
      supportsColor: fields[2] as bool,
      supportsCutting: fields[3] as bool,
      maxPrintWidth: fields[4] as int,
      supportedFormats: (fields[5] as List).cast<String>(),
      supportsBluetooth: fields[6] as bool,
      supportsWifi: fields[7] as bool,
      supportsUsb: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, PrinterCapabilities obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.supportedLabelSizes)
      ..writeByte(1)
      ..write(obj.maxResolutionDpi)
      ..writeByte(2)
      ..write(obj.supportsColor)
      ..writeByte(3)
      ..write(obj.supportsCutting)
      ..writeByte(4)
      ..write(obj.maxPrintWidth)
      ..writeByte(5)
      ..write(obj.supportedFormats)
      ..writeByte(6)
      ..write(obj.supportsBluetooth)
      ..writeByte(7)
      ..write(obj.supportsWifi)
      ..writeByte(8)
      ..write(obj.supportsUsb);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterCapabilitiesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LabelSizeAdapter extends TypeAdapter<LabelSize> {
  @override
  final int typeId = 12;

  @override
  LabelSize read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LabelSize(
      id: fields[0] as String,
      name: fields[1] as String,
      widthMm: fields[2] as double,
      heightMm: fields[3] as double,
      isRoll: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LabelSize obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.widthMm)
      ..writeByte(3)
      ..write(obj.heightMm)
      ..writeByte(4)
      ..write(obj.isRoll);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LabelSizeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrinterConnectionTypeAdapter extends TypeAdapter<PrinterConnectionType> {
  @override
  final int typeId = 13;

  @override
  PrinterConnectionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PrinterConnectionType.bluetooth;
      case 1:
        return PrinterConnectionType.bluetoothLE;
      case 2:
        return PrinterConnectionType.wifi;
      case 3:
        return PrinterConnectionType.usb;
      case 4:
        return PrinterConnectionType.mfi;
      default:
        return PrinterConnectionType.bluetooth;
    }
  }

  @override
  void write(BinaryWriter writer, PrinterConnectionType obj) {
    switch (obj) {
      case PrinterConnectionType.bluetooth:
        writer.writeByte(0);
        break;
      case PrinterConnectionType.bluetoothLE:
        writer.writeByte(1);
        break;
      case PrinterConnectionType.wifi:
        writer.writeByte(2);
        break;
      case PrinterConnectionType.usb:
        writer.writeByte(3);
        break;
      case PrinterConnectionType.mfi:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterConnectionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PrinterStatusAdapter extends TypeAdapter<PrinterStatus> {
  @override
  final int typeId = 14;

  @override
  PrinterStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PrinterStatus.disconnected;
      case 1:
        return PrinterStatus.connecting;
      case 2:
        return PrinterStatus.connected;
      case 3:
        return PrinterStatus.printing;
      case 4:
        return PrinterStatus.error;
      case 5:
        return PrinterStatus.lowBattery;
      case 6:
        return PrinterStatus.outOfLabels;
      case 7:
        return PrinterStatus.coverOpen;
      default:
        return PrinterStatus.disconnected;
    }
  }

  @override
  void write(BinaryWriter writer, PrinterStatus obj) {
    switch (obj) {
      case PrinterStatus.disconnected:
        writer.writeByte(0);
        break;
      case PrinterStatus.connecting:
        writer.writeByte(1);
        break;
      case PrinterStatus.connected:
        writer.writeByte(2);
        break;
      case PrinterStatus.printing:
        writer.writeByte(3);
        break;
      case PrinterStatus.error:
        writer.writeByte(4);
        break;
      case PrinterStatus.lowBattery:
        writer.writeByte(5);
        break;
      case PrinterStatus.outOfLabels:
        writer.writeByte(6);
        break;
      case PrinterStatus.coverOpen:
        writer.writeByte(7);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
