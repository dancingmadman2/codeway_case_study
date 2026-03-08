String generateFileName(String prefix, String extension) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return '${prefix}_$timestamp.$extension';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  } else if (bytes < 1024 * 1024) {
    final kb = (bytes / 1024).toStringAsFixed(1);
    return '$kb KB';
  } else {
    final mb = (bytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB';
  }
}
