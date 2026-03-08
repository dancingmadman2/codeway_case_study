import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';

class DeleteHistoryUseCase {
  final HistoryRepository _historyRepository;
  final StorageRepository _storageRepository;

  DeleteHistoryUseCase(this._historyRepository, this._storageRepository);

  Future<void> call(ProcessingHistory item) async {
    await _storageRepository.deleteFiles([
      item.originalImagePath,
      item.resultPath,
      item.thumbnailPath,
      if (item.pdfPath != null) item.pdfPath!,
    ]);
    await _historyRepository.delete(item.id);
  }
}
