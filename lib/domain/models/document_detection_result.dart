import 'dart:ui';

enum DetectionSource { textEstimation, fused }

/// Lightweight result for real-time camera frame document detection.
class LiveDocumentResult {
  final List<Offset> corners; // 4 points: TL, TR, BR, BL
  final List<Rect> textBlocks;
  final double confidence;
  final DetectionSource source;
  final Size frameSize; // portrait coordinate space of corners

  LiveDocumentResult({
    required this.corners,
    required this.textBlocks,
    this.confidence = 0.0,
    this.source = DetectionSource.textEstimation,
    this.frameSize = Size.zero,
  });
  factory LiveDocumentResult.empty() =>
      LiveDocumentResult(corners: [], textBlocks: []);

  bool get hasDocument => corners.length == 4;
}

class DocumentDetectionResult {
  final List<Offset> cornerPoints;
  final List<Rect> textBlocks;
  final String recognizedText;
  final double edgeConfidence;

  DocumentDetectionResult({
    required this.cornerPoints,
    required this.textBlocks,
    required this.recognizedText,
    this.edgeConfidence = 0.0,
  });

  bool get hasDocument => textBlocks.isNotEmpty;
}
