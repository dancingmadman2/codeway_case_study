import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:codeway_img_proc/app.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/data/repositories/local_storage_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ProcessingTypeAdapter());
  Hive.registerAdapter(ProcessingHistoryAdapter());
  await _migrateAbsolutePaths();
  runApp(const App());
}

/// One-time migration: convert absolute paths to relative paths in Hive.
Future<void> _migrateAbsolutePaths() async {
  final storage = LocalStorageRepository();
  await storage.init();
  final basePath = storage.resolvePathSync('');

  final box = await Hive.openBox<ProcessingHistory>('processing_history');
  for (final key in box.keys) {
    final item = box.get(key);
    if (item == null) continue;

    // Check if any path is absolute (needs migration)
    if (!item.thumbnailPath.startsWith('/') &&
        !item.resultPath.startsWith('/') &&
        !item.originalImagePath.startsWith('/') &&
        (item.pdfPath == null || !item.pdfPath!.startsWith('/'))) {
      continue;
    }

    String stripBase(String path) {
      if (path.startsWith(basePath)) {
        return path.substring(basePath.length);
      }
      return path;
    }

    final migrated = item.copyWith(
      originalImagePath: stripBase(item.originalImagePath),
      resultPath: stripBase(item.resultPath),
      thumbnailPath: stripBase(item.thumbnailPath),
      pdfPath: item.pdfPath != null ? stripBase(item.pdfPath!) : null,
    );
    await box.put(key, migrated);
  }
  await box.close();
}
