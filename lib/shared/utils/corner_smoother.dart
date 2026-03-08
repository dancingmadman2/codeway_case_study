import 'dart:ui';

import 'package:codeway_img_proc/domain/models/document_detection_result.dart';

/// EMA-based temporal corner stabilization for real-time document detection.
/// Smooths detected corners across frames to reduce jitter.
class CornerSmoother {
  static const double _alpha = 0.25; // EMA blend factor — heavier smoothing
  static const double _snapThreshold = 50.0; // px — snap if corner jumps
  static const int _bufferSize = 5;
  static const double _stabilityThreshold = 10.0; // px
  static const double _confidenceAlpha = 0.25; // slower EMA for confidence
  static const int _sourceHysteresis = 3; // frames before source switch

  List<Offset>? _smoothed;
  final List<List<Offset>> _buffer = [];
  double _smoothedConfidence = 0.0;
  DetectionSource _currentSource = DetectionSource.textEstimation;
  int _sourceChangeCount = 0;

  /// True when the corner buffer is full and all corners have low variance.
  bool get isStable {
    if (_buffer.length < _bufferSize) return false;
    for (var i = 0; i < 4; i++) {
      double maxDist = 0;
      for (var a = 0; a < _buffer.length; a++) {
        for (var b = a + 1; b < _buffer.length; b++) {
          final d = (_buffer[a][i] - _buffer[b][i]).distance;
          if (d > maxDist) maxDist = d;
        }
      }
      if (maxDist >= _stabilityThreshold) return false;
    }
    return true;
  }

  /// Returns averaged corners from the stability buffer when stable, null otherwise.
  List<Offset>? get stableCorners {
    if (!isStable) return null;
    return List.generate(4, (i) {
      double dx = 0, dy = 0;
      for (final corners in _buffer) {
        dx += corners[i].dx;
        dy += corners[i].dy;
      }
      return Offset(dx / _buffer.length, dy / _buffer.length);
    });
  }

  /// Smooth an entire [LiveDocumentResult]: corners, confidence, and source.
  LiveDocumentResult smoothResult(LiveDocumentResult raw) {
    final smoothedCorners = smooth(raw.corners);
    final smoothedConfidence = _smoothConfidence(raw.confidence);
    final smoothedSource = _smoothSource(raw.source);

    return LiveDocumentResult(
      corners: smoothedCorners,
      textBlocks: raw.textBlocks,
      confidence: smoothedConfidence,
      source: smoothedSource,
      frameSize: raw.frameSize,
    );
  }

  /// Apply EMA smoothing to new corners.
  /// Returns smoothed corners, or [newCorners] directly on first call / large jump.
  List<Offset> smooth(List<Offset> newCorners) {
    if (newCorners.length != 4) {
      _smoothed = null;
      _buffer.clear();
      return newCorners;
    }

    if (_smoothed == null || _smoothed!.length != 4) {
      _smoothed = List.of(newCorners);
      _buffer.clear();
      _pushToBuffer(_smoothed!);
      return _smoothed!;
    }

    // Check if any corner jumped beyond threshold → snap
    for (var i = 0; i < 4; i++) {
      final dist = (newCorners[i] - _smoothed![i]).distance;
      if (dist > _snapThreshold) {
        _smoothed = List.of(newCorners);
        _buffer.clear();
        _pushToBuffer(_smoothed!);
        return _smoothed!;
      }
    }

    // EMA blend
    _smoothed = List.generate(4, (i) {
      return Offset(
        _alpha * newCorners[i].dx + (1 - _alpha) * _smoothed![i].dx,
        _alpha * newCorners[i].dy + (1 - _alpha) * _smoothed![i].dy,
      );
    });

    _pushToBuffer(_smoothed!);
    return _smoothed!;
  }

  double _smoothConfidence(double rawConfidence) {
    if (_smoothed == null) {
      _smoothedConfidence = rawConfidence;
    } else {
      _smoothedConfidence =
          _confidenceAlpha * rawConfidence + (1 - _confidenceAlpha) * _smoothedConfidence;
    }
    return _smoothedConfidence;
  }

  DetectionSource _smoothSource(DetectionSource rawSource) {
    if (rawSource == _currentSource) {
      _sourceChangeCount = 0;
    } else {
      _sourceChangeCount++;
      if (_sourceChangeCount >= _sourceHysteresis) {
        _currentSource = rawSource;
        _sourceChangeCount = 0;
      }
    }
    return _currentSource;
  }

  void _pushToBuffer(List<Offset> corners) {
    _buffer.add(List.of(corners));
    if (_buffer.length > _bufferSize) {
      _buffer.removeAt(0);
    }
  }

  void reset() {
    _smoothed = null;
    _buffer.clear();
    _smoothedConfidence = 0.0;
    _currentSource = DetectionSource.textEstimation;
    _sourceChangeCount = 0;
  }
}
