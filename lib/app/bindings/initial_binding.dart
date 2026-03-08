import 'package:get/get.dart';
import 'package:codeway_img_proc/data/repositories/hive_history_repository.dart';
import 'package:codeway_img_proc/data/repositories/local_storage_repository.dart';
import 'package:codeway_img_proc/data/services/edge_detection_service.dart';
import 'package:codeway_img_proc/data/services/face_detection_service.dart';
import 'package:codeway_img_proc/data/services/document_detection_service.dart';
import 'package:codeway_img_proc/data/services/image_processing_service.dart';
import 'package:codeway_img_proc/data/services/document_scan_service.dart';
import 'package:codeway_img_proc/data/services/camera_service.dart';
import 'package:codeway_img_proc/domain/repositories/history_repository.dart';
import 'package:codeway_img_proc/domain/repositories/storage_repository.dart';
import 'package:codeway_img_proc/domain/usecases/get_all_history_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/delete_history_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/detect_content_type_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/process_face_image_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/process_document_image_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/search_history_usecase.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<HistoryRepository>(HiveHistoryRepository(), permanent: true);
    final storageRepo = LocalStorageRepository();
    storageRepo.init();
    Get.put<StorageRepository>(storageRepo, permanent: true);

    Get.lazyPut(() => FaceDetectionService(), fenix: true);
    Get.lazyPut(() => EdgeDetectionService(), fenix: true);
    Get.lazyPut(
      () => DocumentDetectionService(Get.find<EdgeDetectionService>()),
      fenix: true,
    );
    Get.lazyPut(() => ImageProcessingService(), fenix: true);
    Get.lazyPut(() => DocumentScanService(), fenix: true);
    Get.lazyPut(() => CameraService(), fenix: true);

    Get.lazyPut(
      () => GetAllHistoryUseCase(Get.find<HistoryRepository>()),
      fenix: true,
    );
    Get.lazyPut(
      () => DeleteHistoryUseCase(
        Get.find<HistoryRepository>(),
        Get.find<StorageRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => SearchHistoryUseCase(Get.find<HistoryRepository>()),
      fenix: true,
    );
    Get.lazyPut(
      () => DetectContentTypeUseCase(
        Get.find<FaceDetectionService>(),
        Get.find<DocumentDetectionService>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ProcessFaceImageUseCase(
        Get.find<FaceDetectionService>(),
        Get.find<ImageProcessingService>(),
        Get.find<StorageRepository>(),
        Get.find<HistoryRepository>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ProcessDocumentImageUseCase(
        Get.find<DocumentDetectionService>(),
        Get.find<ImageProcessingService>(),
        Get.find<DocumentScanService>(),
        Get.find<StorageRepository>(),
        Get.find<HistoryRepository>(),
      ),
      fenix: true,
    );
  }
}
