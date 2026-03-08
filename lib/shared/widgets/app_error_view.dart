import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final IconData icon;
  final String retryLabel;

  const AppErrorView({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
    this.onBack,
    this.icon = Icons.error_outline,
    this.retryLabel = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryLabel),
              ),
            if (onBack != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
