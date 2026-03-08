import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/modules/result/result_controller.dart';
import 'package:codeway_img_proc/modules/result/widgets/before_after_view.dart';
import 'package:codeway_img_proc/modules/result/widgets/pdf_result_view.dart';
import 'package:codeway_img_proc/shared/widgets/app_error_view.dart';
import 'package:codeway_img_proc/shared/utils/date_format_utils.dart';
import 'package:codeway_img_proc/shared/widgets/processing_type_badge.dart';

class ResultScreen extends GetView<ResultController> {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: controller.goHome,
          ),
        ],
      ),
      body: Obx(() {
        final error = controller.errorMessage.value;
        if (error != null) {
          return AppErrorView(
            message: error,
            onBack: controller.goHome,
          );
        }

        return _buildContent();
      }),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTypeBadge(),
                const SizedBox(height: 16),
                if (controller.isFaceResult)
                  BeforeAfterView(
                    originalPath: controller.resolvedOriginalPath,
                    resultPath: controller.resolvedResultPath,
                  )
                else
                  PdfResultView(
                    resolvedOriginalPath: controller.resolvedOriginalPath,
                    resolvedResultPath: controller.resolvedResultPath,
                    history: controller.history,
                    onOpenPdf: controller.openPdf,
                    isOpeningPdf: controller.isOpeningPdf,
                  ),
                const SizedBox(height: 16),
                _buildInfoRow(),
              ],
            ),
          ),
        ),
        _buildBottomActions(),
      ],
    );
  }

  Widget _buildTypeBadge() {
    return Row(
      children: [
        ProcessingTypeBadge(
          type: controller.history.type,
          label: controller.isFaceResult
              ? '${controller.history.facesDetected} face${controller.history.facesDetected != 1 ? 's' : ''} detected'
              : 'PDF',
        ),
      ],
    );
  }

  Widget _buildInfoRow() {
    return Text(
      formatDate(controller.history.createdAt),
      style: const TextStyle(
        color: AppColors.onSurfaceVariant,
        fontSize: 13,
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.surfaceVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: controller.goHome,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }
}
