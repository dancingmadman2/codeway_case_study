import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';

class GetAllHistoryUseCase {
  final HistoryRepository _historyRepository;

  GetAllHistoryUseCase(this._historyRepository);

  Future<List<ProcessingHistory>> call() {
    return _historyRepository.getAll();
  }
}
