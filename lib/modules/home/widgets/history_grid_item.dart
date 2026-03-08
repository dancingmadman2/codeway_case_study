import 'package:flutter/material.dart';
import 'package:codeway_img_proc/domain/models/processing_history.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/shared/utils/date_format_utils.dart';
import 'package:codeway_img_proc/shared/widgets/app_image.dart';

class HistoryGridItem extends StatelessWidget {
  final ProcessingHistory item;
  final String resolvedThumbnailPath;
  final VoidCallback onTap;

  const HistoryGridItem({
    super.key,
    required this.item,
    required this.resolvedThumbnailPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (200 * dpr).round();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(
              path: resolvedThumbnailPath,
              borderRadius: 0,
              cacheWidth: cacheW,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 10,
              child: Text(
                formatDate(item.createdAt),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _buildBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge() {
    final isFace = item.type == ProcessingType.face;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isFace ? '${item.facesDetected}' : 'PDF',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
