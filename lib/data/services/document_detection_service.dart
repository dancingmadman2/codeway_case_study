import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:codeway_img_proc/data/services/edge_detection_service.dart';
import 'package:codeway_img_proc/data/services/isolate_models.dart';
import 'package:codeway_img_proc/domain/models/document_detection_result.dart';

class DocumentDetectionService {
  final EdgeDetectionService _edgeDetectionService;

  /// Fast recognizer for real-time camera frames.
  final TextRecognizer _liveTextRecognizer = TextRecognizer();

  /// Recognizer for post-capture / file-based detection.
  final TextRecognizer _textRecognizer = TextRecognizer();

  DocumentDetectionService(this._edgeDetectionService);

  /// Fast text block detection for real-time camera frames.
  /// Returns bounding quad estimated from text block positions (no OpenCV).
  Future<LiveDocumentResult> detectTextBlocksFast(InputImage inputImage) async {
    final recognized = await _liveTextRecognizer.processImage(inputImage);
    if (recognized.blocks.isEmpty) return LiveDocumentResult.empty();

    final textBlocks = recognized.blocks.map((block) {
      final rect = block.boundingBox;
      return Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);
    }).toList();

    final corners = _estimateCorners(textBlocks);
    return LiveDocumentResult(corners: corners, textBlocks: textBlocks);
  }

  /// Fast document detection using ML Kit text recognition only.
  /// Text block bounding boxes are used directly as the document outline.
  Future<LiveDocumentResult> detectDocumentFast(
    InputImage inputImage,
    CameraImage cameraImage,
    TargetPlatform platform,
    int sensorOrientation,
  ) async {
    final recognized = await _liveTextRecognizer.processImage(inputImage);
    if (recognized.blocks.isEmpty) {
      return LiveDocumentResult.empty();
    }

    final textBlocks = recognized.blocks.map((block) {
      final rect = block.boundingBox;
      return Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);
    }).toList();

    final corners = _estimateCorners(textBlocks);
    return LiveDocumentResult(
      corners: corners,
      textBlocks: textBlocks,
      confidence: 0.7,
      source: DetectionSource.textEstimation,
    );
  }

  Future<DocumentDetectionResult> detectDocument(
    InputImage inputImage, {
    Uint8List? imageBytes,
  }) async {
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final textBlocks = recognizedText.blocks.map((block) {
      final rect = block.boundingBox;
      return Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom);
    }).toList();

    // Try edge detection only if we have text blocks and image bytes
    if (imageBytes != null && textBlocks.isNotEmpty) {
      try {
        final hints = textBlocks
            .map((r) => IsolateRect(r.left, r.top, r.right, r.bottom))
            .toList();
        final edgeResult = await _edgeDetectionService.detectEdges(
          imageBytes,
          textBlockHints: hints,
        );

        final allCandidates = [edgeResult, ...edgeResult.alternatives]
            .where((c) => c.corners.length == 4 && c.confidence > 0.2);

        if (allCandidates.isNotEmpty) {
          final textBounds = _estimateCorners(textBlocks);
          final textRect = _cornersToRect(textBounds);
          final textArea = textRect.width * textRect.height;

          EdgeDetectionOutput? bestCandidate;
          List<Offset>? bestCorners;
          double bestScore = -1;

          for (final candidate in allCandidates) {
            final edgeCorners = candidate.corners
                .map((c) => Offset(c.dx, c.dy))
                .toList();

            final edgeRect = _cornersToRect(edgeCorners);
            final edgeArea = edgeRect.width * edgeRect.height;

            final intersection = textRect.intersect(edgeRect);
            final containment = textArea > 0
                ? (intersection.width * intersection.height) / textArea
                : 0.0;

            // Reject misaligned quads and overly-large folder/desk detections
            if (containment < 0.3 || (textArea > 0 && edgeArea / textArea > 4.0)) {
              debugPrint('[DocDetect] REJECTED cont=${containment.toStringAsFixed(2)} '
                  'areaRatio=${(edgeArea / textArea).toStringAsFixed(2)}');
              continue;
            }

            final areaFit = textArea > 0 ? min(1.0, textArea / edgeArea) : 0.0;
            final score = 0.6 * containment + 0.4 * areaFit;

            debugPrint('[DocDetect] Post-capture candidate '
                'conf=${candidate.confidence.toStringAsFixed(2)} '
                'containment=${containment.toStringAsFixed(2)} '
                'areaRatio=${textArea > 0 ? (edgeArea / textArea).toStringAsFixed(2) : "N/A"} '
                'score=${score.toStringAsFixed(3)}');

            if (score > bestScore) {
              bestScore = score;
              bestCandidate = candidate;
              bestCorners = edgeCorners;
            }
          }

          if (bestCandidate != null && bestCorners != null) {
            debugPrint('[DocDetect] Selected from ${allCandidates.length} candidates '
                'score=${bestScore.toStringAsFixed(3)} '
                'conf=${bestCandidate.confidence.toStringAsFixed(2)}');
            return DocumentDetectionResult(
              cornerPoints: bestCorners,
              textBlocks: textBlocks,
              recognizedText: recognizedText.text,
              edgeConfidence: bestCandidate.confidence,
            );
          }
        }
      } catch (e) {
        debugPrint('[DocDetect] Edge detection failed: $e');
      }
    }

    // Fallback: text-block estimated corners
    final cornerPoints = _estimateCorners(textBlocks);
    debugPrint('[DocDetect] FALLBACK to text-block corners '
        '(${cornerPoints.length} pts)');

    return DocumentDetectionResult(
      cornerPoints: cornerPoints,
      textBlocks: textBlocks,
      recognizedText: recognizedText.text,
      edgeConfidence: 0.0,
    );
  }

  List<Offset> _estimateCorners(List<Rect> textBlocks) {
    if (textBlocks.isEmpty) return [];

    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final block in textBlocks) {
      if (block.left < minX) minX = block.left;
      if (block.top < minY) minY = block.top;
      if (block.right > maxX) maxX = block.right;
      if (block.bottom > maxY) maxY = block.bottom;
    }

    const padding = 30.0;
    return [
      Offset(minX - padding, minY - padding),
      Offset(maxX + padding, minY - padding),
      Offset(maxX + padding, maxY + padding),
      Offset(minX - padding, maxY + padding),
    ];
  }

  Rect _cornersToRect(List<Offset> corners) {
    if (corners.isEmpty) return Rect.zero;
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final c in corners) {
      if (c.dx < minX) minX = c.dx;
      if (c.dy < minY) minY = c.dy;
      if (c.dx > maxX) maxX = c.dx;
      if (c.dy > maxY) maxY = c.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Runs OCR on the given image bytes (e.g. enhanced image) and returns
  /// the recognized text string.
  Future<String> recognizeText(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/ocr_enhanced_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await tempFile.writeAsBytes(imageBytes);
    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      final result = await _textRecognizer.processImage(inputImage);
      return result.text;
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  void dispose() {
    _liveTextRecognizer.close();
    _textRecognizer.close();
  }
}
