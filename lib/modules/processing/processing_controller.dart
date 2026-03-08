import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/data/services/camera_service.dart';
import 'package:codeway_img_proc/domain/models/processing_step.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/domain/usecases/detect_content_type_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/process_face_image_usecase.dart';
import 'package:codeway_img_proc/domain/usecases/process_document_image_usecase.dart';
import 'package:codeway_img_proc/app/routes/app_routes.dart';
import 'package:codeway_img_proc/app/routes/route_arguments.dart';

class ProcessingController extends GetxController {
  final _cameraService = Get.find<CameraService>();
  final _detectContentType = Get.find<DetectContentTypeUseCase>();
  final _processFace = Get.find<ProcessFaceImageUseCase>();
  final _processDocument = Get.find<ProcessDocumentImageUseCase>();

  final currentStep = Rxn<ProcessingStep>();
  final progress = 0.0.obs;
  final detectedType = Rxn<ProcessingType>();
  final errorMessage = Rxn<String>();
  final isUnrecognized = false.obs;

  final imagePath = Rxn<String>();
  late final ProcessingType? _preDetectedType;
  bool _disposed = false;
  int _retryVersion = 0;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as ProcessingArgs;
    imagePath.value = args.imagePath;
    _preDetectedType = args.detectedType;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startProcessing());
  }

  @override
  void onClose() {
    _disposed = true;
    super.onClose();
  }

  Future<void> _startProcessing() async {
    final version = _retryVersion;
    try {
      errorMessage.value = null;
      isUnrecognized.value = false;
      progress.value = 0.0;

      // Step 0: Capture image if needed (camera flow)
      if (imagePath.value == null) {
        currentStep.value = ProcessingStep.capturing;
        progress.value = 0.0;

        final String? path;
        if (_preDetectedType == ProcessingType.face) {
          // Face: use existing camera (already focused on the face).
          // High resolution is sufficient — reinit would lose focus.
          path = await _cameraService.takePicture();
        } else {
          // Document/unknown: reinit at max resolution for text clarity.
          path = await _cameraService.captureAtMaxResolution();
        }
        if (_disposed || _retryVersion != version) return;
        if (path == null) {
          errorMessage.value =
              'Failed to capture image. Please go back and try again.';
          return;
        }
        imagePath.value = path;
      }

      currentStep.value = ProcessingStep.detecting;

      final ProcessingType type;
      if (_preDetectedType != null) {
        // Use the pre-detected type from camera real-time detection.
        // Brief delay so the detecting step is visible.
        await Future.delayed(const Duration(milliseconds: 400));
        if (_disposed || _retryVersion != version) return;
        type = _preDetectedType;
      } else {
        // Fallback: detect from file (gallery picks).
        type = await _detectContentType.call(imagePath.value!);
      }
      if (_disposed || _retryVersion != version) return;
      detectedType.value = type;

      final history = switch (type) {
        ProcessingType.face => await _processFace.call(
            imagePath.value!,
            onProgress: (step, value) {
              if (_disposed || _retryVersion != version) return;
              currentStep.value = step;
              progress.value = value;
            },
          ),
        ProcessingType.document => await _processDocument.call(
            imagePath.value!,
            onProgress: (step, value) {
              if (_disposed || _retryVersion != version) return;
              currentStep.value = step;
              progress.value = value;
            },
          ),
        ProcessingType.unknown => null,
      };

      if (_disposed || _retryVersion != version) return;
      if (history == null) {
        isUnrecognized.value = true;
        return;
      }
      Get.offNamed(AppRoutes.result, arguments: HistoryArgs(history));
    } catch (e) {
      if (_disposed || _retryVersion != version) return;
      errorMessage.value =
          'Processing failed. Please try again with a different image.';
    }
  }

  Future<void> retry() async {
    if (imagePath.value == null) {
      // Capture failure — go back instead of retrying
      Get.back();
      return;
    }
    _retryVersion++;
    _disposed = false;
    await _startProcessing();
  }
}
