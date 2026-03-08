import 'dart:io';
import 'dart:ui';

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:codeway_img_proc/domain/models/face_detection_result.dart';

class FaceDetectionService {
  /// Fast detector for real-time camera frames.
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
    ),
  );

  /// Accurate detector for still images (gallery picks, saved files).
  /// Uses accurate mode and minimum face size of 10% for better detection.
  final FaceDetector _accurateDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.1,
    ),
  );

  /// Detect faces in a camera frame (fast mode).
  Future<FaceDetectionResult> detectFaces(InputImage inputImage) async {
    return _detect(inputImage, _faceDetector);
  }

  /// Detect faces from a file path using accurate mode.
  /// Handles EXIF rotation by decoding with the `image` package and
  /// writing a corrected temp file if direct detection fails.
  Future<FaceDetectionResult> detectFacesFromFile(String imagePath) async {
    try {
      // Try direct file path first (works on iOS, sometimes Android).
      final inputImage = InputImage.fromFilePath(imagePath);
      var result = await _detect(inputImage, _accurateDetector);
      if (result.hasFaces) return result;

      // Fallback: decode with `image` package (auto-applies EXIF rotation),
      // write corrected image to temp file, retry detection.
      final bytes = await File(imagePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return result;

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/face_detect_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final correctedBytes = img.encodeJpg(decoded);
      await File(tempPath).writeAsBytes(correctedBytes);

      try {
        final correctedInput = InputImage.fromFilePath(tempPath);
        result = await _detect(correctedInput, _accurateDetector);
      } finally {
        try {
          File(tempPath).deleteSync();
        } catch (_) {}
      }
      return result;
    } catch (e) {
      return FaceDetectionResult(faceBounds: []);
    }
  }

  Future<FaceDetectionResult> _detect(
      InputImage inputImage, FaceDetector detector) async {
    final faces = await detector.processImage(inputImage);
    final faceBounds = faces
        .map((face) => Rect.fromLTRB(
              face.boundingBox.left,
              face.boundingBox.top,
              face.boundingBox.right,
              face.boundingBox.bottom,
            ))
        .toList();
    return FaceDetectionResult(faceBounds: faceBounds);
  }

  void dispose() {
    _faceDetector.close();
    _accurateDetector.close();
  }
}
