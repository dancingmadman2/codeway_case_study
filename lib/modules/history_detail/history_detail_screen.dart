import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/modules/history_detail/history_detail_controller.dart';
import 'package:codeway_img_proc/shared/utils/date_format_utils.dart';
import 'package:codeway_img_proc/shared/utils/file_utils.dart';
import 'package:codeway_img_proc/shared/utils/snackbar_utils.dart';
import 'package:codeway_img_proc/modules/history_detail/widgets/ocr_section.dart';
import 'package:codeway_img_proc/modules/result/widgets/before_after_view.dart';

class HistoryDetailScreen extends GetView<HistoryDetailController> {
  const HistoryDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BeforeAfterView(
              originalPath: controller.resolvedOriginalPath,
              resultPath: controller.resolvedResultPath,
            ),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),
            if (controller.history.type == ProcessingType.face)
              _buildFaceInfo(),
            if (controller.history.type == ProcessingType.document) ...[
              _buildOpenPdfButton(context),
              if (controller.history.extractedText != null &&
                  controller.history.extractedText!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildOcrSection(context),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final history = controller.history;
    final d = history.createdAt;
    final isFace = history.type == ProcessingType.face;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              Icons.category,
              'Type',
              isFace ? 'Face Processing' : 'Document Scan',
            ),
            const Divider(height: 24, color: AppColors.surfaceVariant),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              formatDate(d),
            ),
            const Divider(height: 24, color: AppColors.surfaceVariant),
            _buildInfoRow(
              Icons.storage,
              'File Size',
              formatFileSize(history.fileSizeBytes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFaceInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.face, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text(
              'Faces detected',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              '${controller.history.facesDetected}',
              style: const TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpenPdfButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Obx(() => ElevatedButton.icon(
        onPressed: controller.isOpeningPdf.value ? null : controller.openPdf,
        icon: controller.isOpeningPdf.value
            ? Theme.of(context).platform == TargetPlatform.iOS
                ? const CupertinoActivityIndicator(radius: 9)
                : const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
            : const Icon(Icons.picture_as_pdf),
        label: const Text('Open PDF'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      )),
    );
  }

  Widget _buildOcrSection(BuildContext context) {
    return OcrSection(
      extractedText: controller.history.extractedText!,
      onCopy: () {
        Clipboard.setData(
          ClipboardData(text: controller.history.extractedText!),
        );
        showAppSnackbar('Copied', 'Text copied to clipboard');
      },
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Item'),
        content: const Text('Are you sure you want to delete this item?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.deleteAndGoBack();
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
