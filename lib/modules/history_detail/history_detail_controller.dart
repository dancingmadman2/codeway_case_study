import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';
import 'package:codeway_img_proc/domain/usecases/delete_history_usecase.dart';
import 'package:codeway_img_proc/app/routes/route_arguments.dart';
import 'package:codeway_img_proc/shared/utils/snackbar_utils.dart';

class HistoryDetailController extends GetxController {
  final _deleteHistory = Get.find<DeleteHistoryUseCase>();
  final _storage = Get.find<StorageRepository>();
  late final ProcessingHistory history;
  late final String resolvedOriginalPath;
  late final String resolvedResultPath;
  late final String? resolvedPdfPath;
  final isDeleting = false.obs;
  final isOpeningPdf = false.obs;

  @override
  void onInit() {
    super.onInit();
    history = (Get.arguments as HistoryArgs).history;
    resolvedOriginalPath = _storage.resolvePathSync(history.originalImagePath);
    resolvedResultPath = _storage.resolvePathSync(history.resultPath);
    resolvedPdfPath = history.pdfPath != null
        ? _storage.resolvePathSync(history.pdfPath!)
        : null;
  }

  Future<void> deleteAndGoBack() async {
    if (isDeleting.value) return;
    try {
      isDeleting.value = true;
      await _deleteHistory.call(history);
      Get.back(result: true);
    } catch (e) {
      showAppSnackbar('Error', 'Failed to delete item');
    } finally {
      isDeleting.value = false;
    }
  }

  Future<void> openPdf() async {
    if (isOpeningPdf.value) return;
    try {
      isOpeningPdf.value = true;
      if (history.type == ProcessingType.document) {
        await OpenFilex.open(resolvedPdfPath ?? resolvedResultPath);
      }
    } catch (e) {
      showAppSnackbar('Error', 'Failed to open PDF');
    } finally {
      isOpeningPdf.value = false;
    }
  }
}
