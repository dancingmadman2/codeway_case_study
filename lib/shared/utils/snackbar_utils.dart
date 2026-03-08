import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';

void showAppSnackbar(String title, String message) {
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppColors.surfaceVariant,
    colorText: AppColors.onSurface,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
    duration: const Duration(seconds: 3),
  );
}
