import 'dart:io';

import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';

class AppImage extends StatelessWidget {
  final String path;
  final double? height;
  final double? width;
  final BoxFit fit;
  final double borderRadius;
  final IconData errorIcon;
  final FilterQuality filterQuality;
  final int? cacheWidth;

  const AppImage({
    super.key,
    required this.path,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
    this.borderRadius = 12,
    this.errorIcon = Icons.broken_image,
    this.filterQuality = FilterQuality.medium,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        File(path),
        height: height,
        width: width,
        fit: fit,
        filterQuality: filterQuality,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => Container(
          height: height,
          width: width,
          color: AppColors.surfaceVariant,
          child: Center(
            child: Icon(
              errorIcon,
              size: height != null ? (height! * 0.2).clamp(32, 64) : 48,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
