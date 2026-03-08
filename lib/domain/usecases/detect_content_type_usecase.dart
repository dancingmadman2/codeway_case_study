import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:codeway_img_proc/data/services/face_detection_service.dart';
import 'package:codeway_img_proc/data/services/document_detection_service.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';

class DetectContentTypeUseCase {
  final FaceDetectionService _faceDetectionService;
  final DocumentDetectionService _documentDetectionService;

  DetectContentTypeUseCase(this._faceDetectionService, this._documentDetectionService);

  /// Detect content type from a saved image file.
  /// Uses accurate-mode face detection for better reliability on still images.
  Future<ProcessingType> call(String imagePath) async {
    final faceResult =
        await _faceDetectionService.detectFacesFromFile(imagePath);
    if (faceResult.hasFaces) return ProcessingType.face;

    final inputImage = InputImage.fromFilePath(imagePath);
    final docResult = await _documentDetectionService.detectDocument(inputImage);
    if (docResult.hasDocument) return ProcessingType.document;

    return ProcessingType.unknown;
  }
}
