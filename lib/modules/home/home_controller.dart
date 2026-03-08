import 'dart:async';

import 'package:get/get.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';
import 'package:codeway_img_proc/domain/usecases/get_all_history_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/delete_history_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/search_history_usecase.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:codeway_img_proc/app/routes/app_routes.dart';
import 'package:codeway_img_proc/app/routes/route_arguments.dart';
import 'package:codeway_img_proc/data/services/camera_service.dart';
import 'package:codeway_img_proc/shared/utils/snackbar_utils.dart';

class HomeController extends GetxController {
  final _getAllHistory = Get.find<GetAllHistoryUseCase>();
  final _deleteHistory = Get.find<DeleteHistoryUseCase>();
  final _searchHistory = Get.find<SearchHistoryUseCase>();
  final _storage = Get.find<StorageRepository>();

  final historyItems = <ProcessingHistory>[].obs;
  final resolvedThumbnails = <String, String>{}.obs;
  final isLoading = true.obs;
  final errorMessage = Rxn<String>();

  final isSearching = false.obs;
  final searchQuery = ''.obs;
  final _filteredItems = <ProcessingHistory>[].obs;
  Timer? _searchDebounce;

  List<ProcessingHistory> get displayItems =>
      isSearching.value && searchQuery.value.isNotEmpty
          ? _filteredItems
          : historyItems;

  @override
  void onInit() {
    super.onInit();
    loadHistory();
    _warmUpCamera();
  }

  Future<void> _warmUpCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      Get.find<CameraService>().warmUp();
    }
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> loadHistory() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final items = await _getAllHistory.call();
      historyItems.value = items;
      resolvedThumbnails.value = {
        for (final item in items)
          item.id: _storage.resolvePathSync(item.thumbnailPath),
      };
    } catch (e) {
      errorMessage.value = 'Failed to load history';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteItem(ProcessingHistory item) async {
    try {
      await _deleteHistory.call(item);
      historyItems.remove(item);
      _filteredItems.remove(item);
    } catch (e) {
      showAppSnackbar('Error', 'Failed to delete item');
    }
  }

  void toggleSearch() {
    isSearching.value = !isSearching.value;
    if (!isSearching.value) {
      searchQuery.value = '';
      _filteredItems.clear();
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query;
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _filteredItems.clear();
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await _searchHistory.call(query);
      _filteredItems.value = results;
    });
  }

  void navigateToCapture() => Get.toNamed(AppRoutes.capture);

  void navigateToDetail(ProcessingHistory item) =>
      Get.toNamed(AppRoutes.historyDetail, arguments: HistoryArgs(item));
}
