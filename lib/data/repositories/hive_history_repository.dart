import 'package:hive_ce/hive.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';

class HiveHistoryRepository implements HistoryRepository {
  static const _boxName = 'processing_history';

  Box<ProcessingHistory>? _box;

  Future<Box<ProcessingHistory>> get box async {
    _box ??= await Hive.openBox<ProcessingHistory>(_boxName);
    return _box!;
  }

  @override
  Future<List<ProcessingHistory>> getAll() async {
    final b = await box;
    final items = b.values.toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<ProcessingHistory?> getById(String id) async {
    final b = await box;
    return b.get(id);
  }

  @override
  Future<void> save(ProcessingHistory item) async {
    final b = await box;
    await b.put(item.id, item);
  }

  @override
  Future<void> delete(String id) async {
    final b = await box;
    await b.delete(id);
  }
}
