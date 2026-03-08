import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:codeway_img_proc/data/services/document_detection_service.dart';
import 'package:codeway_img_proc/data/services/document_scan_service.dart';
import 'package:codeway_img_proc/data/services/image_processing_service.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_step.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';

class ProcessDocumentImageUseCase {
  final DocumentDetectionService _documentDetectionService;
  final ImageProcessingService _imageProcessingService;
  final DocumentScanService _documentScanService;
  final StorageRepository _storageRepository;
  final HistoryRepository _historyRepository;

  ProcessDocumentImageUseCase(
    this._documentDetectionService,
    this._imageProcessingService,
    this._documentScanService,
    this._storageRepository,
    this._historyRepository,
  );

  Future<ProcessingHistory> call(
    String imagePath, {
    Function(ProcessingStep, double)? onProgress,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();

    Uint8List workingImage = imageBytes;

    // Always run full detection pipeline (same path for camera and gallery)
    onProgress?.call(ProcessingStep.detecting, 0.0);
    final inputImage = InputImage.fromFilePath(imagePath);
    final docResult = await _documentDetectionService.detectDocument(
      inputImage,
      imageBytes: imageBytes,
    );
    onProgress?.call(ProcessingStep.docEdgeDetection, 0.15);
    final recognizedTextFallback = docResult.recognizedText;

    if (docResult.edgeConfidence >= 0.5 &&
        docResult.cornerPoints.length == 4) {
      onProgress?.call(ProcessingStep.docEdgeDetection, 0.30);
      debugPrint('[DocProcess] Applying perspective transform '
          '(conf=${docResult.edgeConfidence.toStringAsFixed(2)})');
      final corners = docResult.cornerPoints
          .map((p) => Offset(p.dx, p.dy))
          .toList();
      workingImage = await _documentScanService.perspectiveTransform(
        imageBytes,
        corners,
      );
    } else {
      debugPrint('[DocProcess] Skipping transform '
          '(conf=${docResult.edgeConfidence.toStringAsFixed(2)}) — CLAHE only');
    }

    // CLAHE enhance
    onProgress?.call(ProcessingStep.docContrastEnhance, 0.50);
    final enhanced =
        await _imageProcessingService.enhanceDocument(workingImage);

    // OCR on enhanced image
    onProgress?.call(ProcessingStep.docOcrEnhanced, 0.60);
    final enhancedText =
        await _documentDetectionService.recognizeText(enhanced);
    final extractedText = enhancedText.isNotEmpty
        ? enhancedText
        : recognizedTextFallback;

    // PDF export
    onProgress?.call(ProcessingStep.docPdfExport, 0.75);
    final pdfBytes = await _documentScanService.exportToPdf(enhanced);

    // Save results
    onProgress?.call(ProcessingStep.saving, 0.85);
    final thumbnail = await _imageProcessingService.createThumbnail(enhanced);
    final resultPath = await _storageRepository.saveImage(enhanced);
    final pdfPath = await _storageRepository.savePdf(pdfBytes);
    final thumbnailPath = await _storageRepository.saveThumbnail(thumbnail);
    final fileSize = await _storageRepository.getFileSize(pdfPath);
    final originalPath = await _storageRepository.saveOriginal(imagePath);

    final history = ProcessingHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ProcessingType.document,
      originalImagePath: originalPath,
      resultPath: resultPath,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now(),
      fileSizeBytes: fileSize,
      extractedText: extractedText,
      pdfPath: pdfPath,
    );

    await _historyRepository.save(history);
    onProgress?.call(ProcessingStep.saving, 1.0);

    return history;
  }
}
