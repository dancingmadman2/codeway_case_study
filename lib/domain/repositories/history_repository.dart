import 'package:codeway_img_proc/domain/models/processing_history.dart';

abstract class HistoryRepository {
  Future<List<ProcessingHistory>> getAll();
  Future<ProcessingHistory?> getById(String id);
  Future<void> save(ProcessingHistory item);
  Future<void> delete(String id);
}
