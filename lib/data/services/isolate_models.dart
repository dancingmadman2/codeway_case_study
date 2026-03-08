import 'dart:typed_data';

/// Plain Dart types for passing data across isolate boundaries.
/// dart:ui types (Rect, Offset) cannot cross isolate boundaries.

class IsolateRect {
  final double left, top, right, bottom;
  const IsolateRect(this.left, this.top, this.right, this.bottom);
}

class IsolateOffset {
  final double dx, dy;
  const IsolateOffset(this.dx, this.dy);
}

class CropFacesInput {
  final Uint8List imageBytes;
  final List<IsolateRect> faceBounds;
  const CropFacesInput(this.imageBytes, this.faceBounds);
}

class CompositeFacesInput {
  final Uint8List originalBytes;
  final List<Uint8List> faceImages;
  final List<IsolateRect> bounds;
  const CompositeFacesInput(this.originalBytes, this.faceImages, this.bounds);
}

class ThumbnailInput {
  final Uint8List imageBytes;
  final int width;
  const ThumbnailInput(this.imageBytes, {this.width = 200});
}

class EdgeDetectionInput {
  final Uint8List imageBytes;
  final List<IsolateRect>? textBlockHints;
  const EdgeDetectionInput(this.imageBytes, {this.textBlockHints});
}

class EdgeDetectionOutput {
  final List<IsolateOffset> corners;
  final double confidence;
  final List<EdgeDetectionOutput> alternatives;
  const EdgeDetectionOutput(this.corners, this.confidence, {this.alternatives = const []});
}

class CameraFrameEdgeInput {
  final Uint8List planeBytes;
  final int width;
  final int height;
  final int bytesPerRow;
  final bool isBGRA;
  const CameraFrameEdgeInput(
    this.planeBytes,
    this.width,
    this.height,
    this.bytesPerRow, {
    this.isBGRA = false,
  });
}

class PerspectiveTransformInput {
  final Uint8List imageBytes;
  final List<IsolateOffset> cornerPoints;
  const PerspectiveTransformInput(this.imageBytes, this.cornerPoints);
}
