import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  final String? message;

  const AppLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final indicator = Theme.of(context).platform == TargetPlatform.iOS
        ? const CupertinoActivityIndicator(radius: 14)
        : CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          );

    final children = <Widget>[indicator];

    if (message != null) {
      children.add(const SizedBox(height: 16));
      children.add(
        Text(
          message!,
          style: const TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
