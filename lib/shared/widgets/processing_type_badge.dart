import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';

class ProcessingTypeBadge extends StatelessWidget {
  final ProcessingType type;
  final String? label;

  const ProcessingTypeBadge({
    super.key,
    required this.type,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, defaultLabel) = switch (type) {
      ProcessingType.face => (Icons.face, 'Face Detected'),
      ProcessingType.document => (Icons.description, 'Document Detected'),
      ProcessingType.unknown => (Icons.help_outline, 'Unknown'),
    };
    final displayLabel = label ?? defaultLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.onSurface,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            displayLabel,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
