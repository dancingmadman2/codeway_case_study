import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/modules/processing/processing_controller.dart';
import 'package:codeway_img_proc/modules/processing/widgets/processing_step_indicator.dart';
import 'package:codeway_img_proc/shared/widgets/app_image.dart';
import 'package:codeway_img_proc/shared/widgets/app_error_view.dart';
import 'package:codeway_img_proc/shared/widgets/processing_type_badge.dart';

class ProcessingScreen extends GetView<ProcessingController> {
  const ProcessingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing'),
        automaticallyImplyLeading: false,
      ),
      body: Obx(() {
        final error = controller.errorMessage.value;
        if (error != null) {
          return AppErrorView(
            message: error,
            onRetry: controller.retry,
            onBack: () => Get.back(),
          );
        }

        if (controller.isUnrecognized.value) {
          return _buildUnrecognizedView();
        }

        return _buildProcessingView();
      }),
    );
  }

  Widget _buildUnrecognizedView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final path = controller.imagePath.value;
              if (path == null) return const SizedBox(height: 240);
              return AppImage(
                path: path,
                height: 240,
                width: double.infinity,
                borderRadius: 16,
                errorIcon: Icons.image,
              );
            }),
            const SizedBox(height: 32),
            AppErrorView(
              icon: Icons.image_not_supported_outlined,
              message: 'No face or document detected in this image.',
              onBack: () => Get.back(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() {
              final path = controller.imagePath.value;
              if (path == null) return const SizedBox(height: 240);
              return AppImage(
                path: path,
                height: 240,
                width: double.infinity,
                borderRadius: 16,
                errorIcon: Icons.image,
              );
            }),
            const SizedBox(height: 32),
            Obx(() => ProcessingStepIndicator(
                  step: controller.currentStep.value,
                  progress: controller.progress.value,
                )),
            const SizedBox(height: 24),
            Obx(() {
              final type = controller.detectedType.value;
              if (type == null) return const SizedBox.shrink();
              return ProcessingTypeBadge(type: type);
            }),
          ],
        ),
      ),
    );
  }
}
