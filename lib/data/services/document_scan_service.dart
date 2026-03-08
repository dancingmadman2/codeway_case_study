import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:codeway_img_proc/data/services/isolate_models.dart';

class DocumentScanService {
  /// Apply perspective transform to rectify a document given 4 corner points.
  Future<Uint8List> perspectiveTransform(
    Uint8List imageBytes,
    List<Offset> cornerPoints,
  ) {
    final input = PerspectiveTransformInput(
      imageBytes,
      cornerPoints.map((p) => IsolateOffset(p.dx, p.dy)).toList(),
    );
    return compute(_perspectiveTransformIsolate, input);
  }

  static Uint8List _perspectiveTransformIsolate(PerspectiveTransformInput input) {
    final src = cv.imdecode(input.imageBytes, cv.IMREAD_COLOR);
    if (src.isEmpty) return input.imageBytes;

    try {
      final pts = input.cornerPoints;
      if (pts.length != 4) return input.imageBytes;

      // Estimate output dimensions from corner distances
      final outW = _estimateEdgeLength(
        [pts[0].dx, pts[0].dy],
        [pts[1].dx, pts[1].dy],
        [pts[3].dx, pts[3].dy],
        [pts[2].dx, pts[2].dy],
      );
      final outH = _estimateEdgeLength(
        [pts[0].dx, pts[0].dy],
        [pts[3].dx, pts[3].dy],
        [pts[1].dx, pts[1].dy],
        [pts[2].dx, pts[2].dy],
      );

      // Cap at 2× source dimensions to avoid huge output
      final maxW = src.cols * 3;
      final maxH = src.rows * 3;
      final w = min(outW, maxW);
      final h = min(outH, maxH);

      if (w < 10 || h < 10) return input.imageBytes;

      final srcPts = cv.VecPoint.fromList([
        cv.Point(pts[0].dx.round(), pts[0].dy.round()),
        cv.Point(pts[1].dx.round(), pts[1].dy.round()),
        cv.Point(pts[2].dx.round(), pts[2].dy.round()),
        cv.Point(pts[3].dx.round(), pts[3].dy.round()),
      ]);
      final dstPts = cv.VecPoint.fromList([
        cv.Point(0, 0),
        cv.Point(w, 0),
        cv.Point(w, h),
        cv.Point(0, h),
      ]);

      final matrix = cv.getPerspectiveTransform(srcPts, dstPts);
      srcPts.dispose();
      dstPts.dispose();

      final warped = cv.warpPerspective(src, matrix, (w, h));
      matrix.dispose();

      final (_, encoded) = cv.imencode('.png', warped);
      warped.dispose();
      return encoded;
    } catch (e) {
      debugPrint('[DocScan] Perspective transform failed: $e');
      return input.imageBytes;
    } finally {
      src.dispose();
    }
  }

  static int _estimateEdgeLength(
    List<double> a1,
    List<double> a2,
    List<double> b1,
    List<double> b2,
  ) {
    final d1 = sqrt(pow(a2[0] - a1[0], 2) + pow(a2[1] - a1[1], 2));
    final d2 = sqrt(pow(b2[0] - b1[0], 2) + pow(b2[1] - b1[1], 2));
    return max(d1, d2).round();
  }

  /// Trim white borders from image post-perspective transform.
  Future<Uint8List> trimWhiteBorders(Uint8List imageBytes) {
    return compute(_trimWhiteBordersIsolate, imageBytes);
  }

  static Uint8List _trimWhiteBordersIsolate(Uint8List imageBytes) {
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return imageBytes;

    final trimmed = img.trim(decoded, mode: img.TrimMode.topLeftColor);
    if (trimmed.width < 10 || trimmed.height < 10) return imageBytes;

    return Uint8List.fromList(img.encodePng(trimmed));
  }

  Future<Uint8List> exportToPdf(Uint8List imageBytes) async {
    final doc = pw.Document(
      title: 'Scanned Document',
      creator: 'Codeway Image Processor',
    );

    final image = pw.MemoryImage(imageBytes);

    // Decode to get dimensions for aspect-ratio-aware fitting
    final decoded = img.decodeImage(imageBytes);
    final imgWidth = decoded?.width.toDouble() ?? 595.0;
    final imgHeight = decoded?.height.toDouble() ?? 842.0;

    const margin = 8.0;

    // Scale image to fit within A4-ish max bounds, then size page to image
    const maxPageWidth = 595.0; // A4 width in points
    const maxPageHeight = 842.0; // A4 height in points
    const maxAvailWidth = maxPageWidth - 2 * margin;
    const maxAvailHeight = maxPageHeight - 2 * margin;

    final scaleX = maxAvailWidth / imgWidth;
    final scaleY = maxAvailHeight / imgHeight;
    final downScale = min(scaleX, scaleY);

    // Images smaller than A4 → scale up to fill (as before).
    // Images larger than A4 → map pixels to points at 150 DPI to preserve
    // detail while keeping a reasonable page size.
    final double fitWidth;
    final double fitHeight;
    if (downScale >= 1.0) {
      // Image fits within A4 — scale up to fill
      fitWidth = imgWidth * downScale;
      fitHeight = imgHeight * downScale;
    } else {
      // Image exceeds A4 — use 150 DPI mapping (points = pixels × 72/150)
      const dpiScale = 72.0 / 150.0;
      fitWidth = imgWidth * dpiScale;
      fitHeight = imgHeight * dpiScale;
    }

    // Size page to image aspect ratio (not fixed A4)
    final pageWidth = fitWidth + 2 * margin;
    final pageHeight = fitHeight + 2 * margin;

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(pageWidth, pageHeight),
        margin: const pw.EdgeInsets.all(margin),
        build: (context) => pw.Center(
          child: pw.Image(
            image,
            width: fitWidth,
            height: fitHeight,
          ),
        ),
      ),
    );

    return Uint8List.fromList(await doc.save());
  }
}
