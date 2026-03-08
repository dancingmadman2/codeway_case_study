import 'dart:io';
import 'dart:typed_data';

import 'package:codeway_img_proc/data/services/face_detection_service.dart';
import 'package:codeway_img_proc/data/services/image_processing_service.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_step.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';
import 'package:image/image.dart' as img;

class ProcessFaceImageUseCase {
  final FaceDetectionService _faceDetectionService;
  final ImageProcessingService _imageProcessingService;
  final StorageRepository _storageRepository;
  final HistoryRepository _historyRepository;

  ProcessFaceImageUseCase(
    this._faceDetectionService,
    this._imageProcessingService,
    this._storageRepository,
    this._historyRepository,
  );

  Future<ProcessingHistory> call(
    String imagePath, {
    Function(ProcessingStep, double)? onProgress,
  }) async {
    // Decode with `image` package to handle EXIF rotation, then re-encode
    // so face bounds from detection align with the pixel data used for cropping.
    final rawBytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(rawBytes);
    final imageBytes =
        decoded != null ? Uint8List.fromList(img.encodeJpg(decoded)) : rawBytes;

    onProgress?.call(ProcessingStep.detecting, 0.0);
    final faceResult =
        await _faceDetectionService.detectFacesFromFile(imagePath);

    onProgress?.call(ProcessingStep.faceCropping, 0.25);
    final croppedFaces = await _imageProcessingService.cropFaces(
      imageBytes,
      faceResult.faceBounds,
    );

    onProgress?.call(ProcessingStep.faceFilter, 0.50);
    final filteredFaces = await _imageProcessingService.applyGrayscale(
      croppedFaces,
    );

    onProgress?.call(ProcessingStep.faceComposite, 0.75);
    final compositeBytes = await _imageProcessingService.compositeFaces(
      imageBytes,
      filteredFaces,
      faceResult.faceBounds,
    );

    onProgress?.call(ProcessingStep.saving, 0.90);
    final thumbnail = await _imageProcessingService.createThumbnail(
      compositeBytes,
    );
    final resultPath = await _storageRepository.saveImage(compositeBytes);
    final thumbnailPath = await _storageRepository.saveThumbnail(thumbnail);
    final fileSize = await _storageRepository.getFileSize(resultPath);
    final originalPath = await _storageRepository.saveOriginal(imagePath);

    final history = ProcessingHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: ProcessingType.face,
      originalImagePath: originalPath,
      resultPath: resultPath,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.now(),
      fileSizeBytes: fileSize,
      facesDetected: faceResult.faceBounds.length,
    );

    await _historyRepository.save(history);
    onProgress?.call(ProcessingStep.saving, 1.0);

    return history;
  }
}
