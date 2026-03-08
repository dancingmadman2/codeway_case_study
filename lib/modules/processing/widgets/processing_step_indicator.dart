import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/domain/models/processing_step.dart';

class ProcessingStepIndicator extends StatelessWidget {
  final ProcessingStep? step;
  final double progress;

  const ProcessingStepIndicator({
    super.key,
    required this.step,
    required this.progress,
  });

  IconData _iconForStep(ProcessingStep step) {
    return switch (step) {
      ProcessingStep.capturing => Icons.camera_alt,
      ProcessingStep.detecting => Icons.search,
      ProcessingStep.faceDetection => Icons.face,
      ProcessingStep.faceCropping => Icons.crop,
      ProcessingStep.faceFilter => Icons.auto_fix_high,
      ProcessingStep.faceComposite => Icons.layers,
      ProcessingStep.docEdgeDetection => Icons.crop_free,
      ProcessingStep.docPerspectiveTransform => Icons.transform,
      ProcessingStep.docCrop => Icons.crop,
      ProcessingStep.docContrastEnhance => Icons.contrast,
      ProcessingStep.docOcrEnhanced => Icons.text_fields,
      ProcessingStep.docPdfExport => Icons.picture_as_pdf,
      ProcessingStep.saving => Icons.save,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (step != null) ...[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              _iconForStep(step!),
              key: ValueKey(step),
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              step!.description,
              key: ValueKey(step),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            builder: (context, animatedProgress, _) {
              return LinearProgressIndicator(
                value: animatedProgress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceVariant,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(progress * 100).toInt()}%',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
