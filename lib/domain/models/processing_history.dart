import 'package:hive_ce/hive.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';

part 'processing_history.g.dart';

@HiveType(typeId: 1)
class ProcessingHistory {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final ProcessingType type;

  @HiveField(2)
  final String originalImagePath;

  @HiveField(3)
  final String resultPath;

  @HiveField(4)
  final String thumbnailPath;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  final int fileSizeBytes;

  @HiveField(7)
  final String? extractedText;

  @HiveField(8)
  final int facesDetected;

  @HiveField(9)
  final String? pdfPath;

  ProcessingHistory({
    required this.id,
    required this.type,
    required this.originalImagePath,
    required this.resultPath,
    required this.thumbnailPath,
    required this.createdAt,
    required this.fileSizeBytes,
    this.extractedText,
    this.facesDetected = 0,
    this.pdfPath,
  });

  ProcessingHistory copyWith({
    String? originalImagePath,
    String? resultPath,
    String? thumbnailPath,
    String? pdfPath,
  }) {
    return ProcessingHistory(
      id: id,
      type: type,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      resultPath: resultPath ?? this.resultPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt,
      fileSizeBytes: fileSizeBytes,
      extractedText: extractedText,
      facesDetected: facesDetected,
      pdfPath: pdfPath ?? this.pdfPath,
    );
  }
}
