import 'package:flutter/material.dart';
import 'package:codeway_img_proc/domain/models/document_detection_result.dart';
import 'package:codeway_img_proc/domain/models/face_detection_result.dart';

class CameraOverlayPainter extends CustomPainter {
  final FaceDetectionResult? faceResult;
  final LiveDocumentResult? documentResult;
  final Size previewSize;

  CameraOverlayPainter({
    required this.faceResult,
    this.documentResult,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // width↔height swap is intentional: camera sensor is landscape (90° rotated)
    // but the preview is displayed in portrait, so we map sensor height → screen
    // width and sensor width → screen height.
    final scaleX = size.width / previewSize.height;
    final scaleY = size.height / previewSize.width;

    // Draw face bounding boxes (existing logic) — faces take priority
    if (faceResult != null && faceResult!.hasFaces) {
      _paintFaces(canvas, size, scaleX, scaleY);
      return;
    }

    // Draw document edge guides + corner markers
    if (documentResult != null && documentResult!.hasDocument) {
      _paintDocumentEdges(canvas, size, scaleX, scaleY);
    }
  }

  void _paintFaces(Canvas canvas, Size size, double scaleX, double scaleY) {
    final paint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (final bound in faceResult!.faceBounds) {
      final scaledRect = Rect.fromLTRB(
        bound.left * scaleX,
        bound.top * scaleY,
        bound.right * scaleX,
        bound.bottom * scaleY,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(scaledRect, const Radius.circular(8)),
        paint,
      );
    }
  }

  void _paintDocumentEdges(
      Canvas canvas, Size size, double scaleX, double scaleY) {
    final corners = documentResult!.corners;

    // Use actual frame dimensions for document overlay scaling when available,
    // instead of previewSize which can differ from CameraImage dimensions on iOS.
    final fs = documentResult!.frameSize;
    final docScaleX = fs.width > 0 ? size.width / fs.width : scaleX;
    final docScaleY = fs.height > 0 ? size.height / fs.height : scaleY;

    // Scale corners to preview coordinates
    final scaled =
        corners.map((c) => Offset(c.dx * docScaleX, c.dy * docScaleY)).toList();

    // Color based on detection confidence:
    // green = edge-detected (high confidence), orange = text-only (low confidence)
    final confidence = documentResult!.confidence;
    final edgeColor = Color.lerp(
      const Color(0xFFFF9800), // orange (text-only)
      const Color(0xFF4CAF50), // green (edge-detected)
      confidence.clamp(0.0, 1.0),
    )!;

    // Draw quad outline
    final edgePaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path()
      ..moveTo(scaled[0].dx, scaled[0].dy)
      ..lineTo(scaled[1].dx, scaled[1].dy)
      ..lineTo(scaled[2].dx, scaled[2].dy)
      ..lineTo(scaled[3].dx, scaled[3].dy)
      ..close();
    canvas.drawPath(path, edgePaint);

    // Draw corner markers (L-shaped brackets)
    final cornerPaint = Paint()
      ..color = edgeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const markerLen = 24.0;
    for (var i = 0; i < 4; i++) {
      final curr = scaled[i];
      final next = scaled[(i + 1) % 4];
      final prev = scaled[(i + 3) % 4];

      final toNext = _unitVector(curr, next) * markerLen;
      final toPrev = _unitVector(curr, prev) * markerLen;

      canvas.drawLine(curr, curr + toNext, cornerPaint);
      canvas.drawLine(curr, curr + toPrev, cornerPaint);
    }

    // Semi-transparent fill inside the quad
    final fillPaint = Paint()
      ..color = edgeColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  static Offset _unitVector(Offset from, Offset to) {
    final d = to - from;
    final len = d.distance;
    return len > 0 ? d / len : Offset.zero;
  }

  @override
  bool shouldRepaint(CameraOverlayPainter oldDelegate) {
    return oldDelegate.faceResult != faceResult ||
        oldDelegate.documentResult != documentResult;
  }
}
