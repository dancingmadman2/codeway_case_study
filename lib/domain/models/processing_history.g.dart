// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'processing_history.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProcessingHistoryAdapter extends TypeAdapter<ProcessingHistory> {
  @override
  final typeId = 1;

  @override
  ProcessingHistory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProcessingHistory(
      id: fields[0] as String,
      type: fields[1] as ProcessingType,
      originalImagePath: fields[2] as String,
      resultPath: fields[3] as String,
      thumbnailPath: fields[4] as String,
      createdAt: fields[5] as DateTime,
      fileSizeBytes: (fields[6] as num).toInt(),
      extractedText: fields[7] as String?,
      facesDetected: fields[8] == null ? 0 : (fields[8] as num).toInt(),
      pdfPath: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProcessingHistory obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.originalImagePath)
      ..writeByte(3)
      ..write(obj.resultPath)
      ..writeByte(4)
      ..write(obj.thumbnailPath)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.fileSizeBytes)
      ..writeByte(7)
      ..write(obj.extractedText)
      ..writeByte(8)
      ..write(obj.facesDetected)
      ..writeByte(9)
      ..write(obj.pdfPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProcessingHistoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
