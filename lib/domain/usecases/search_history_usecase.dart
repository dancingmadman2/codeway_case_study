import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';

class SearchHistoryUseCase {
  final HistoryRepository _historyRepository;

  SearchHistoryUseCase(this._historyRepository);

  Future<List<ProcessingHistory>> call(String query) async {
    final all = await _historyRepository.getAll();
    final lower = query.toLowerCase();
    return all
        .where(
            (item) => item.extractedText?.toLowerCase().contains(lower) ?? false)
        .toList();
  }
}
