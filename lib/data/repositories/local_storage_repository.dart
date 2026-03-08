import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';

class LocalStorageRepository implements StorageRepository {
  Directory? _baseDir;

  @override
  Future<void> init() async {
    _baseDir = await getApplicationDocumentsDirectory();
  }

  Future<Directory> _getSubDir(String name) async {
    _baseDir ??= await getApplicationDocumentsDirectory();
    final dir = Directory('${_baseDir!.path}/$name');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  @override
  String resolvePathSync(String path) {
    if (path.startsWith('/')) return path;
    return '${_baseDir!.path}/$path';
  }

  @override
  Future<String> saveImage(Uint8List bytes) async {
    final dir = await _getSubDir('processed');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/img_$timestamp.png');
    await file.writeAsBytes(bytes);
    return 'processed/img_$timestamp.png';
  }

  @override
  Future<String> saveThumbnail(Uint8List bytes) async {
    final dir = await _getSubDir('thumbnails');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/thumb_$timestamp.png');
    await file.writeAsBytes(bytes);
    return 'thumbnails/thumb_$timestamp.png';
  }

  @override
  Future<String> savePdf(Uint8List bytes) async {
    final dir = await _getSubDir('scans');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/doc_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    return 'scans/doc_$timestamp.pdf';
  }

  @override
  Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      final resolved = resolvePathSync(path);
      final file = File(resolved);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<String> saveOriginal(String sourcePath) async {
    final dir = await _getSubDir('originals');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = sourcePath.split('.').last;
    final dest = File('${dir.path}/orig_$timestamp.$ext');
    await File(sourcePath).copy(dest.path);
    return 'originals/orig_$timestamp.$ext';
  }

  @override
  Future<int> getFileSize(String path) async {
    final resolved = resolvePathSync(path);
    final file = File(resolved);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }
}
