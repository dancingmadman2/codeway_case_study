import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/modules/result/widgets/before_after_view.dart';
import 'package:codeway_img_proc/shared/utils/snackbar_utils.dart';
import 'package:codeway_img_proc/shared/widgets/searchable_ocr_text.dart';

class PdfResultView extends StatelessWidget {
  final String resolvedOriginalPath;
  final String resolvedResultPath;
  final ProcessingHistory history;
  final VoidCallback onOpenPdf;
  final RxBool isOpeningPdf;

  const PdfResultView({
    super.key,
    required this.resolvedOriginalPath,
    required this.resolvedResultPath,
    required this.history,
    required this.onOpenPdf,
    required this.isOpeningPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BeforeAfterView(
          originalPath: resolvedOriginalPath,
          resultPath: resolvedResultPath,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Obx(() => ElevatedButton.icon(
            onPressed: isOpeningPdf.value ? null : onOpenPdf,
            icon: isOpeningPdf.value
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
        ),
        if (history.extractedText != null &&
            history.extractedText!.isNotEmpty) ...[
          const SizedBox(height: 16),
          SearchableOcrText(
            text: history.extractedText!,
            onCopy: () {
              Clipboard.setData(
                ClipboardData(text: history.extractedText!),
              );
              showAppSnackbar('Copied', 'Text copied to clipboard');
            },
          ),
        ],
      ],
    );
  }
}
