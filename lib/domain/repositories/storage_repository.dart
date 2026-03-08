import 'dart:typed_data';

abstract class StorageRepository {
  Future<void> init();
  Future<String> saveImage(Uint8List bytes);
  Future<String> saveThumbnail(Uint8List bytes);
  Future<String> savePdf(Uint8List bytes);
  Future<void> deleteFiles(List<String> paths);
  Future<int> getFileSize(String path);
  Future<String> saveOriginal(String sourcePath);
  String resolvePathSync(String path);
}
