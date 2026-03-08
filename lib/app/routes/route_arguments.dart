import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';

/// Arguments for the processing route — expects an image file path.
class ProcessingArgs {
  final String? imagePath;

  /// Pre-detected content type from camera real-time detection.
  /// When non-null, skips redundant content-type detection in processing.
  final ProcessingType? detectedType;

  const ProcessingArgs(
    this.imagePath, {
    this.detectedType,
  });
}

/// Arguments for routes that receive a ProcessingHistory (result, history_detail).
class HistoryArgs {
  final ProcessingHistory history;
  const HistoryArgs(this.history);
}
