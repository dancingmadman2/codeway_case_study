import 'dart:io';

import 'package:flutter/material.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/shared/widgets/app_image.dart';

class _ImageEntry {
  final String path;
  final String label;
  const _ImageEntry(this.path, this.label);
}

class BeforeAfterView extends StatelessWidget {
  final String originalPath;
  final String resultPath;

  const BeforeAfterView({
    super.key,
    required this.originalPath,
    required this.resultPath,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildImageSection(context, 'Original', originalPath, 0)),
        const SizedBox(width: 8),
        Expanded(child: _buildImageSection(context, 'Processed', resultPath, 1)),
      ],
    );
  }

  Widget _buildImageSection(BuildContext context, String label, String path, int index) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showFullScreenImage(context, index),
          child: Hero(
            tag: 'image_hero_$path',
            child: AppImage(
              path: path,
              width: double.infinity,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, int initialIndex) {
    final images = [
      _ImageEntry(originalPath, 'Original'),
      _ImageEntry(resultPath, 'Processed'),
    ];
    final initialHeroTag = 'image_hero_${images[initialIndex].path}';
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, _) {
          return FadeTransition(
            opacity: animation,
            child: _FullScreenImageViewer(
              images: images,
              initialIndex: initialIndex,
              initialHeroTag: initialHeroTag,
            ),
          );
        },
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<_ImageEntry> images;
  final int initialIndex;
  final String initialHeroTag;

  const _FullScreenImageViewer({
    required this.images,
    required this.initialIndex,
    required this.initialHeroTag,
  });

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  late final List<TransformationController> _transformControllers;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _transformControllers = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    for (final tc in _transformControllers) {
      tc.addListener(_onTransformChanged);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final tc in _transformControllers) {
      tc.removeListener(_onTransformChanged);
      tc.dispose();
    }
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformControllers[_currentIndex].value.getMaxScaleOnAxis();
    final zoomed = scale > 1.01;
    if (zoomed != _isZoomed) {
      setState(() => _isZoomed = zoomed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.images[_currentIndex].label),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final image = Image.file(
                File(widget.images[index].path),
                fit: BoxFit.contain,
              );
              final child = index == widget.initialIndex
                  ? Hero(tag: widget.initialHeroTag, child: image)
                  : image;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: InteractiveViewer(
                    transformationController: _transformControllers[index],
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: child,
                  ),
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (index) {
                final isActive = index == _currentIndex;
                return Container(
                  width: isActive ? 10 : 8,
                  height: isActive ? 10 : 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
