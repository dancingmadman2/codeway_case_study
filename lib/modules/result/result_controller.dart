import 'dart:io';

import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';
import 'package:codeway_img_proc/app/routes/app_routes.dart';
import 'package:codeway_img_proc/app/routes/route_arguments.dart';
import 'package:codeway_img_proc/shared/utils/snackbar_utils.dart';

class ResultController extends GetxController {
  final _storage = Get.find<StorageRepository>();
  late final ProcessingHistory history;
  late final String resolvedOriginalPath;
  late final String resolvedResultPath;
  late final String? resolvedPdfPath;
  final errorMessage = Rxn<String>();
  final isOpeningPdf = false.obs;

  bool get isFaceResult => history.type == ProcessingType.face;
  bool get isDocResult => history.type == ProcessingType.document;

  @override
  void onInit() {
    super.onInit();
    history = (Get.arguments as HistoryArgs).history;
    resolvedOriginalPath = _storage.resolvePathSync(history.originalImagePath);
    resolvedResultPath = _storage.resolvePathSync(history.resultPath);
    resolvedPdfPath = history.pdfPath != null
        ? _storage.resolvePathSync(history.pdfPath!)
        : null;
    _validateFiles();
  }

  void _validateFiles() {
    if (!File(resolvedResultPath).existsSync()) {
      errorMessage.value = 'Result file is missing';
    } else if (isFaceResult && !File(resolvedOriginalPath).existsSync()) {
      errorMessage.value = 'Original image is missing';
    }
  }

  void goHome() => Get.offAllNamed(AppRoutes.home);

  Future<void> openPdf() async {
    if (isOpeningPdf.value) return;
    try {
      isOpeningPdf.value = true;
      if (isDocResult) {
        await OpenFilex.open(resolvedPdfPath ?? resolvedResultPath);
      }
    } catch (e) {
      showAppSnackbar('Error', 'Failed to open PDF');
    } finally {
      isOpeningPdf.value = false;
    }
  }
}
