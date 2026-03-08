import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'package:codeway_img_proc/data/services/isolate_models.dart';

class EdgeDetectionService {
  /// Lightweight edge detection for real-time camera frames.
  /// Uses raw Y-plane (Android) or BGRA (iOS) data — no decode overhead.
  Future<EdgeDetectionOutput> detectEdgesFromCameraFrameAsync(
    CameraFrameEdgeInput input,
  ) {
    return compute(_detectEdgesFromCameraFrame, input);
  }

  /// Full-quality edge detection from encoded image bytes.
  Future<EdgeDetectionOutput> detectEdges(
    Uint8List imageBytes, {
    List<IsolateRect>? textBlockHints,
  }) {
    return compute(
      _detectEdgesIsolate,
      EdgeDetectionInput(imageBytes, textBlockHints: textBlockHints),
    );
  }

  // ---------------------------------------------------------------------------
  // Camera frame isolate (lightweight, ~800px processing)
  // ---------------------------------------------------------------------------

  static EdgeDetectionOutput _detectEdgesFromCameraFrame(
    CameraFrameEdgeInput input,
  ) {
    cv.Mat gray;
    if (input.isBGRA) {
      final mat = cv.Mat.fromList(
        input.height,
        input.width,
        cv.MatType.CV_8UC4,
        input.planeBytes,
      );
      gray = cv.cvtColor(mat, cv.COLOR_BGRA2GRAY);
      mat.dispose();
    } else {
      gray = cv.Mat.fromList(
        input.height,
        input.bytesPerRow,
        cv.MatType.CV_8UC1,
        input.planeBytes,
      );
      if (gray.cols != input.width) {
        final cropped = gray.region(cv.Rect(0, 0, input.width, input.height));
        gray.dispose();
        gray = cropped.clone();
        cropped.dispose();
      }
    }

    // Downscale for speed (800px gives ~1.8× more pixels for contour detection)
    const maxDim = 800;
    final scale = maxDim / max(gray.rows, gray.cols);
    cv.Mat small;
    if (scale < 1.0) {
      small = cv.resize(gray, (0, 0), fx: scale, fy: scale);
      gray.dispose();
    } else {
      small = gray;
    }

    final realScale = scale < 1.0 ? scale : 1.0;

    // Preprocessing: bilateral filter to suppress text, preserve edges
    final blurred = cv.bilateralFilter(small, 7, 50, 50);
    small.dispose();

    // Adaptive Canny via Otsu
    final edges = _adaptiveCanny(blurred);
    blurred.dispose();

    // Strategy A: contour detection
    final resultA = _findQuadFromContours(edges, realScale);
    if (resultA.corners.isNotEmpty && resultA.confidence > 0.4) {
      edges.dispose();
      return resultA;
    }

    // Collect Strategy A candidates for attachment to fallback results
    final aCandidates = [
      if (resultA.corners.isNotEmpty) resultA,
      ...resultA.alternatives,
    ];

    // Strategy B: Hough line intersections
    final resultB = _findQuadFromHoughLines(edges, realScale);

    if (resultB.corners.isNotEmpty) {
      edges.dispose();
      return EdgeDetectionOutput(
        resultB.corners,
        resultB.confidence,
        alternatives: [...resultB.alternatives, ...aCandidates],
      );
    }

    // Strategy C: Border edge scan (fallback for documents on contrasting backgrounds)
    final resultC = _findQuadFromBorderScan(edges, realScale);
    edges.dispose();

    if (resultC.corners.isNotEmpty) {
      return EdgeDetectionOutput(
        resultC.corners,
        resultC.confidence,
        alternatives: [...resultC.alternatives, ...aCandidates],
      );
    }
    if (resultA.corners.isNotEmpty) return resultA;

    return const EdgeDetectionOutput([], 0.0);
  }

  // ---------------------------------------------------------------------------
  // Full-quality isolate (~1000px processing, three-strategy cascade)
  // ---------------------------------------------------------------------------

  static EdgeDetectionOutput _detectEdgesIsolate(EdgeDetectionInput input) {
    final src = cv.imdecode(input.imageBytes, cv.IMREAD_COLOR);
    if (src.isEmpty) {
      return const EdgeDetectionOutput([], 0.0);
    }

    try {
      // Downscale for processing
      const maxDim = 1000;
      final scale = maxDim / max(src.rows, src.cols);
      cv.Mat work;
      if (scale < 1.0) {
        work = cv.resize(src, (0, 0), fx: scale, fy: scale);
      } else {
        work = src.clone();
      }

      final realScale = scale < 1.0 ? scale : 1.0;

      // Convert to grayscale and apply bilateral filter
      final gray = cv.cvtColor(work, cv.COLOR_BGR2GRAY);
      work.dispose();
      final filtered = cv.bilateralFilter(gray, 7, 50, 50);
      gray.dispose();

      // Adaptive Canny
      final edges = _adaptiveCanny(filtered);
      filtered.dispose();

      // Strategy A: Improved contour detection (lower threshold for better recall)
      final resultA = _findQuadFromContours(edges, realScale);
      if (resultA.corners.isNotEmpty && resultA.confidence > 0.4) {
        edges.dispose();
        return resultA;
      }

      // Collect Strategy A candidates for attachment to fallback results
      final aCandidates = [
        if (resultA.corners.isNotEmpty) resultA,
        ...resultA.alternatives,
      ];

      // Strategy B: Hough line intersections
      final resultB = _findQuadFromHoughLines(edges, realScale);

      if (resultB.corners.isNotEmpty) {
        // Strategy C not needed if B succeeds
        edges.dispose();
        return EdgeDetectionOutput(
          resultB.corners,
          resultB.confidence,
          alternatives: [...resultB.alternatives, ...aCandidates],
        );
      }

      // Strategy C: Border edge scan (full-quality only)
      final resultC = _findQuadFromBorderScan(edges, realScale);
      edges.dispose();

      if (resultC.corners.isNotEmpty) {
        return EdgeDetectionOutput(
          resultC.corners,
          resultC.confidence,
          alternatives: [...resultC.alternatives, ...aCandidates],
        );
      }
      if (resultA.corners.isNotEmpty) return resultA;

      // Fallback: text block bounding box
      if (input.textBlockHints != null && input.textBlockHints!.isNotEmpty) {
        final fb = _textBlockFallback(
          input.textBlockHints!,
          src.cols.toDouble(),
          src.rows.toDouble(),
        );
        return EdgeDetectionOutput(fb, 0.15);
      }

      return const EdgeDetectionOutput([], 0.0);
    } finally {
      src.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Adaptive Canny (replaces fixed 50/150 thresholds)
  // ---------------------------------------------------------------------------

  static cv.Mat _adaptiveCanny(cv.Mat blurred) {
    final (otsuThresh, otsuMat) =
        cv.threshold(blurred, 0, 255, cv.THRESH_OTSU);
    otsuMat.dispose();
    final edges = cv.canny(blurred, otsuThresh * 0.5, otsuThresh);
    return edges;
  }

  // ---------------------------------------------------------------------------
  // Strategy A — Improved Contour Detection
  // ---------------------------------------------------------------------------

  static EdgeDetectionOutput _findQuadFromContours(
    cv.Mat edgeMap,
    double scale, {
    double minAreaRatio = 0.08,
    double minPerimeterRatio = 0.40,
    int kernelSize = 3,
  }) {
    final kernel =
        cv.getStructuringElement(cv.MORPH_RECT, (kernelSize, kernelSize));
    final closed =
        cv.morphologyEx(edgeMap, cv.MORPH_CLOSE, kernel, iterations: 2);
    kernel.dispose();

    final (contours, hierarchy) = cv.findContours(
      closed,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );
    hierarchy.dispose();
    closed.dispose();

    final imageArea = edgeMap.rows * edgeMap.cols;
    final imagePerimeter = 2.0 * (edgeMap.rows + edgeMap.cols);
    final List<EdgeDetectionOutput> allCandidates = [];

    for (var i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final area = cv.contourArea(contour);

      if (area < imageArea * minAreaRatio || area > imageArea * 0.95) continue;

      final peri = cv.arcLength(contour, true);
      if (peri < imagePerimeter * minPerimeterRatio) continue;

      final approx = cv.approxPolyDP(contour, 0.02 * peri, true);
      if (approx.length != 4) {
        approx.dispose();
        continue;
      }
      final pts = List.generate(
        4,
        (j) => [approx[j].x.toDouble(), approx[j].y.toDouble()],
      );
      approx.dispose();

      if (!_isConvex(pts)) continue;

      final ordered = _orderCorners(pts);
      if (!_validateAngles(ordered)) continue;
      if (!_validateAspectRatio(ordered)) continue;

      final confidence = _computeConfidence(ordered, area, imageArea);

      final corners = ordered
          .map((p) => IsolateOffset(p[0] / scale, p[1] / scale))
          .toList();
      allCandidates.add(EdgeDetectionOutput(corners, confidence));
    }
    contours.dispose();

    if (allCandidates.isEmpty) return const EdgeDetectionOutput([], 0.0);

    // Sort by confidence descending — best is primary, rest are alternatives
    allCandidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    final best = allCandidates.first;
    final alternatives = allCandidates.sublist(1);
    return EdgeDetectionOutput(best.corners, best.confidence, alternatives: alternatives);
  }

  // ---------------------------------------------------------------------------
  // Strategy B — Hough Line Intersections
  // ---------------------------------------------------------------------------

  static EdgeDetectionOutput _findQuadFromHoughLines(
      cv.Mat edgeMap, double scale) {
    // Dilate to connect nearby edge fragments
    final dilateKernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
    final dilated = cv.dilate(edgeMap, dilateKernel);
    dilateKernel.dispose();

    final dim = max(edgeMap.rows, edgeMap.cols).toDouble();
    final lines = cv.HoughLinesP(
      dilated,
      1,
      pi / 180,
      50,
      minLineLength: dim * 0.15,
      maxLineGap: dim * 0.05,
    );
    dilated.dispose();

    if (lines.rows == 0) {
      lines.dispose();
      return const EdgeDetectionOutput([], 0.0);
    }

    final centerX = edgeMap.cols / 2.0;
    final centerY = edgeMap.rows / 2.0;

    // Classify lines into 4 groups: top, bottom, left, right
    // Each entry: [x1, y1, x2, y2, length]
    final List<List<double>> topLines = [];
    final List<List<double>> bottomLines = [];
    final List<List<double>> leftLines = [];
    final List<List<double>> rightLines = [];

    // Border margin: skip lines whose endpoints all hug the image edge
    final borderMargin = dim * 0.05;
    bool isNearBorder(double x, double y) =>
        x < borderMargin ||
        x > edgeMap.cols - borderMargin ||
        y < borderMargin ||
        y > edgeMap.rows - borderMargin;

    for (var i = 0; i < lines.rows; i++) {
      final line = lines.at<cv.Vec4i>(i, 0);
      final x1 = line.val1.toDouble();
      final y1 = line.val2.toDouble();
      final x2 = line.val3.toDouble();
      final y2 = line.val4.toDouble();
      line.dispose();

      // Skip lines that hug the image border (table/device edges)
      if (isNearBorder(x1, y1) && isNearBorder(x2, y2)) continue;

      final length =
          sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));

      final angle = atan2((y2 - y1).abs(), (x2 - x1).abs()) * 180 / pi;
      final avgY = (y1 + y2) / 2;
      final avgX = (x1 + x2) / 2;

      final entry = [x1, y1, x2, y2, length];

      if (angle < 30) {
        // Near-horizontal
        if (avgY < centerY) {
          topLines.add(entry);
        } else {
          bottomLines.add(entry);
        }
      } else if (angle > 60) {
        // Near-vertical
        if (avgX < centerX) {
          leftLines.add(entry);
        } else {
          rightLines.add(entry);
        }
      }
      // Lines between 30-60° are skipped (diagonal, unlikely paper edge)
    }
    lines.dispose();

    // Need at least one line per group
    if (topLines.isEmpty ||
        bottomLines.isEmpty ||
        leftLines.isEmpty ||
        rightLines.isEmpty) {
      return const EdgeDetectionOutput([], 0.0);
    }

    // Pick longest line from each group
    final topLine = _longestLine(topLines);
    final bottomLine = _longestLine(bottomLines);
    final leftLine = _longestLine(leftLines);
    final rightLine = _longestLine(rightLines);

    // Compute 4 corner intersections
    final tl = _lineIntersection(topLine, leftLine);
    final tr = _lineIntersection(topLine, rightLine);
    final br = _lineIntersection(bottomLine, rightLine);
    final bl = _lineIntersection(bottomLine, leftLine);

    if (tl == null || tr == null || br == null || bl == null) {
      return const EdgeDetectionOutput([], 0.0);
    }

    // Validate corners are within image bounds (strict 2% margin)
    final margin = dim * 0.02;
    final allCorners = [tl, tr, br, bl];
    for (final c in allCorners) {
      if (c[0] < -margin ||
          c[0] > edgeMap.cols + margin ||
          c[1] < -margin ||
          c[1] > edgeMap.rows + margin) {
        return const EdgeDetectionOutput([], 0.0);
      }
    }

    final ordered = _orderCorners(allCorners);
    if (!_isConvex(ordered)) return const EdgeDetectionOutput([], 0.0);
    if (!_validateAngles(ordered)) return const EdgeDetectionOutput([], 0.0);
    if (!_validateAspectRatio(ordered)) return const EdgeDetectionOutput([], 0.0);

    // Validate quad area is 10-90% of image (reject full-frame or tiny quads)
    final area = _quadArea(ordered);
    final imageArea = edgeMap.rows * edgeMap.cols;
    final areaRatio = area / imageArea;
    if (areaRatio < 0.10 || areaRatio > 0.90) {
      return const EdgeDetectionOutput([], 0.0);
    }
    final confidence =
        (_computeConfidence(ordered, area, imageArea) + 0.1).clamp(0.0, 1.0);

    final corners = ordered
        .map((p) => IsolateOffset(p[0] / scale, p[1] / scale))
        .toList();
    return EdgeDetectionOutput(corners, confidence);
  }

  /// Pick the longest line from a list of [x1, y1, x2, y2, length].
  static List<double> _longestLine(List<List<double>> lines) {
    var best = lines[0];
    for (var i = 1; i < lines.length; i++) {
      if (lines[i][4] > best[4]) best = lines[i];
    }
    return best;
  }

  /// Compute intersection of two lines given as [x1, y1, x2, y2, ...].
  /// Returns [x, y] or null if lines are parallel.
  static List<double>? _lineIntersection(List<double> l1, List<double> l2) {
    final x1 = l1[0], y1 = l1[1], x2 = l1[2], y2 = l1[3];
    final x3 = l2[0], y3 = l2[1], x4 = l2[2], y4 = l2[3];

    final denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
    if (denom.abs() < 1e-6) return null;

    final t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom;

    return [x1 + t * (x2 - x1), y1 + t * (y2 - y1)];
  }

  /// Compute area of a quadrilateral using the shoelace formula.
  static double _quadArea(List<List<double>> pts) {
    double area = 0;
    for (var i = 0; i < 4; i++) {
      final j = (i + 1) % 4;
      area += pts[i][0] * pts[j][1];
      area -= pts[j][0] * pts[i][1];
    }
    return area.abs() / 2;
  }

  // ---------------------------------------------------------------------------
  // Strategy C — Border Edge Scan (full-quality only)
  // ---------------------------------------------------------------------------

  static EdgeDetectionOutput _findQuadFromBorderScan(
      cv.Mat edgeMap, double scale) {
    final rows = edgeMap.rows;
    final cols = edgeMap.cols;
    const numSamples = 20;

    // Compute Sobel gradients
    final sobelX = cv.sobel(edgeMap, cv.MatType.CV_16S, 1, 0, ksize: 3);
    final sobelY = cv.sobel(edgeMap, cv.MatType.CV_16S, 0, 1, ksize: 3);

    // For each border, scan inward to find the first strong edge
    final topEdgePoints = <List<double>>[];
    final bottomEdgePoints = <List<double>>[];
    final leftEdgePoints = <List<double>>[];
    final rightEdgePoints = <List<double>>[];

    final scanDepth = (min(rows, cols) * 0.4).toInt();
    const gradThreshold = 30;

    // Top border: scan downward at evenly spaced x positions
    for (var s = 0; s < numSamples; s++) {
      final x = ((s + 0.5) * cols / numSamples).toInt().clamp(0, cols - 1);
      for (var y = 0; y < scanDepth; y++) {
        final gy = sobelY.at<int>(y, x).abs();
        if (gy > gradThreshold) {
          topEdgePoints.add([x.toDouble(), y.toDouble()]);
          break;
        }
      }
    }

    // Bottom border: scan upward
    for (var s = 0; s < numSamples; s++) {
      final x = ((s + 0.5) * cols / numSamples).toInt().clamp(0, cols - 1);
      for (var y = rows - 1; y >= rows - scanDepth; y--) {
        final gy = sobelY.at<int>(y, x).abs();
        if (gy > gradThreshold) {
          bottomEdgePoints.add([x.toDouble(), y.toDouble()]);
          break;
        }
      }
    }

    // Left border: scan rightward
    for (var s = 0; s < numSamples; s++) {
      final y = ((s + 0.5) * rows / numSamples).toInt().clamp(0, rows - 1);
      for (var x = 0; x < scanDepth; x++) {
        final gx = sobelX.at<int>(y, x).abs();
        if (gx > gradThreshold) {
          leftEdgePoints.add([x.toDouble(), y.toDouble()]);
          break;
        }
      }
    }

    // Right border: scan leftward
    for (var s = 0; s < numSamples; s++) {
      final y = ((s + 0.5) * rows / numSamples).toInt().clamp(0, rows - 1);
      for (var x = cols - 1; x >= cols - scanDepth; x--) {
        final gx = sobelX.at<int>(y, x).abs();
        if (gx > gradThreshold) {
          rightEdgePoints.add([x.toDouble(), y.toDouble()]);
          break;
        }
      }
    }

    sobelX.dispose();
    sobelY.dispose();

    // Need enough points per border to fit a line
    const minPoints = 5;
    if (topEdgePoints.length < minPoints ||
        bottomEdgePoints.length < minPoints ||
        leftEdgePoints.length < minPoints ||
        rightEdgePoints.length < minPoints) {
      return const EdgeDetectionOutput([], 0.0);
    }

    // Fit lines using median approach (robust to outliers)
    final topLine = _fitLineFromPoints(topEdgePoints, horizontal: true);
    final bottomLine = _fitLineFromPoints(bottomEdgePoints, horizontal: true);
    final leftLine = _fitLineFromPoints(leftEdgePoints, horizontal: false);
    final rightLine = _fitLineFromPoints(rightEdgePoints, horizontal: false);

    // Compute intersections
    final tl = _lineIntersection(topLine, leftLine);
    final tr = _lineIntersection(topLine, rightLine);
    final br = _lineIntersection(bottomLine, rightLine);
    final bl = _lineIntersection(bottomLine, leftLine);

    if (tl == null || tr == null || br == null || bl == null) {
      return const EdgeDetectionOutput([], 0.0);
    }

    // Validate within bounds
    final dim = max(rows, cols).toDouble();
    final margin = dim * 0.1;
    for (final c in [tl, tr, br, bl]) {
      if (c[0] < -margin ||
          c[0] > cols + margin ||
          c[1] < -margin ||
          c[1] > rows + margin) {
        return const EdgeDetectionOutput([], 0.0);
      }
    }

    final ordered = _orderCorners([tl, tr, br, bl]);
    if (!_isConvex(ordered)) return const EdgeDetectionOutput([], 0.0);
    if (!_validateAngles(ordered)) return const EdgeDetectionOutput([], 0.0);
    if (!_validateAspectRatio(ordered)) return const EdgeDetectionOutput([], 0.0);

    final area = _quadArea(ordered);
    final imageArea = rows * cols;
    final confidence = _computeConfidence(ordered, area, imageArea);

    final corners = ordered
        .map((p) => IsolateOffset(p[0] / scale, p[1] / scale))
        .toList();
    return EdgeDetectionOutput(corners, confidence);
  }

  /// Fit a line from edge points using median.
  /// Returns [x1, y1, x2, y2, 0] (length unused, just for compatibility).
  /// For horizontal lines: use median y, span full x range.
  /// For vertical lines: use median x, span full y range.
  static List<double> _fitLineFromPoints(
    List<List<double>> points, {
    required bool horizontal,
  }) {
    if (horizontal) {
      // Sort by y and take median
      final ys = points.map((p) => p[1]).toList()..sort();
      final medianY = ys[ys.length ~/ 2];
      // Use leftmost and rightmost x to define the line
      final xs = points.map((p) => p[0]).toList()..sort();
      return [xs.first, medianY, xs.last, medianY, 0];
    } else {
      // Sort by x and take median
      final xs = points.map((p) => p[0]).toList()..sort();
      final medianX = xs[xs.length ~/ 2];
      final ys = points.map((p) => p[1]).toList()..sort();
      return [medianX, ys.first, medianX, ys.last, 0];
    }
  }

  // ---------------------------------------------------------------------------
  // Shared validation + utility helpers
  // ---------------------------------------------------------------------------

  static bool _validateAngles(List<List<double>> pts) {
    for (var i = 0; i < 4; i++) {
      final a = pts[(i + 3) % 4];
      final b = pts[i];
      final c = pts[(i + 1) % 4];

      final ba = [a[0] - b[0], a[1] - b[1]];
      final bc = [c[0] - b[0], c[1] - b[1]];

      final dot = ba[0] * bc[0] + ba[1] * bc[1];
      final magBA = sqrt(ba[0] * ba[0] + ba[1] * ba[1]);
      final magBC = sqrt(bc[0] * bc[0] + bc[1] * bc[1]);

      if (magBA < 1e-6 || magBC < 1e-6) return false;

      final cosAngle = (dot / (magBA * magBC)).clamp(-1.0, 1.0);
      final angle = acos(cosAngle) * 180 / pi;

      if (angle < 60 || angle > 150) return false;
    }
    return true;
  }

  static bool _validateAspectRatio(List<List<double>> pts) {
    final topWidth = _dist(pts[0], pts[1]);
    final bottomWidth = _dist(pts[3], pts[2]);
    final leftHeight = _dist(pts[0], pts[3]);
    final rightHeight = _dist(pts[1], pts[2]);

    final avgWidth = (topWidth + bottomWidth) / 2;
    final avgHeight = (leftHeight + rightHeight) / 2;

    if (avgHeight < 1e-6) return false;
    final ratio = avgWidth / avgHeight;
    return ratio >= 0.3 && ratio <= 3.0;
  }

  static double _computeConfidence(
    List<List<double>> pts,
    double area,
    int imageArea,
  ) {
    // Area score: peaks around 30-60% of image
    final areaRatio = area / imageArea;
    final areaScore = (areaRatio > 0.1 && areaRatio < 0.8) ? 0.4 : 0.2;

    // Angle regularity: how close each angle is to 90°
    double angleDeviation = 0;
    for (var i = 0; i < 4; i++) {
      final a = pts[(i + 3) % 4];
      final b = pts[i];
      final c = pts[(i + 1) % 4];

      final ba = [a[0] - b[0], a[1] - b[1]];
      final bc = [c[0] - b[0], c[1] - b[1]];
      final dot = ba[0] * bc[0] + ba[1] * bc[1];
      final magBA = sqrt(ba[0] * ba[0] + ba[1] * ba[1]);
      final magBC = sqrt(bc[0] * bc[0] + bc[1] * bc[1]);
      final cosAngle = (dot / (magBA * magBC)).clamp(-1.0, 1.0);
      final angle = acos(cosAngle) * 180 / pi;
      angleDeviation += (angle - 90).abs();
    }
    final angleScore = 0.6 * (1.0 - (angleDeviation / 240).clamp(0.0, 1.0));

    return (areaScore + angleScore).clamp(0.0, 1.0);
  }

  static double _dist(List<double> a, List<double> b) {
    final dx = a[0] - b[0];
    final dy = a[1] - b[1];
    return sqrt(dx * dx + dy * dy);
  }

  static bool _isConvex(List<List<double>> pts) {
    bool? sign;
    for (var i = 0; i < 4; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % 4];
      final c = pts[(i + 2) % 4];
      final cross =
          (b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0]);
      if (cross.abs() < 1e-6) continue;
      final s = cross > 0;
      if (sign == null) {
        sign = s;
      } else if (sign != s) {
        return false;
      }
    }
    return true;
  }

  /// Order corners: top-left, top-right, bottom-right, bottom-left.
  static List<List<double>> _orderCorners(List<List<double>> pts) {
    final sums = pts.map((p) => p[0] + p[1]).toList();
    final diffs = pts.map((p) => p[1] - p[0]).toList();

    final tl = pts[_indexOfMin(sums)];
    final br = pts[_indexOfMax(sums)];
    final tr = pts[_indexOfMin(diffs)];
    final bl = pts[_indexOfMax(diffs)];

    return [tl, tr, br, bl];
  }

  static List<IsolateOffset> _textBlockFallback(
    List<IsolateRect> textBlocks,
    double imageWidth,
    double imageHeight,
  ) {
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

    for (final b in textBlocks) {
      if (b.left < minX) minX = b.left;
      if (b.top < minY) minY = b.top;
      if (b.right > maxX) maxX = b.right;
      if (b.bottom > maxY) maxY = b.bottom;
    }

    const pad = 20.0;
    minX = max(0, minX - pad);
    minY = max(0, minY - pad);
    maxX = min(imageWidth, maxX + pad);
    maxY = min(imageHeight, maxY + pad);

    return [
      IsolateOffset(minX, minY),
      IsolateOffset(maxX, minY),
      IsolateOffset(maxX, maxY),
      IsolateOffset(minX, maxY),
    ];
  }

  static int _indexOfMin(List<double> values) {
    var idx = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] < values[idx]) idx = i;
    }
    return idx;
  }

  static int _indexOfMax(List<double> values) {
    var idx = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[idx]) idx = i;
    }
    return idx;
  }
}
