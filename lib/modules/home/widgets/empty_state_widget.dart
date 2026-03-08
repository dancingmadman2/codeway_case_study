import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No images yet',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap + to get started',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
