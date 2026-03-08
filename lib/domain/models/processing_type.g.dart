// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_type.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProcessingTypeAdapter extends TypeAdapter<ProcessingType> {
  @override
  final typeId = 0;

  @override
  ProcessingType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ProcessingType.face;
      case 1:
        return ProcessingType.document;
      case 2:
        return ProcessingType.unknown;
      default:
        return ProcessingType.face;
    }
  }

  @override
  void write(BinaryWriter writer, ProcessingType obj) {
    switch (obj) {
      case ProcessingType.face:
        writer.writeByte(0);
      case ProcessingType.document:
        writer.writeByte(1);
      case ProcessingType.unknown:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
