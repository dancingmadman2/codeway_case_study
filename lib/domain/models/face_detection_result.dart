import 'dart:ui';

class FaceDetectionResult {
  final List<Rect> faceBounds;

  FaceDetectionResult({required this.faceBounds});

  bool get hasFaces => faceBounds.isNotEmpty;
}
