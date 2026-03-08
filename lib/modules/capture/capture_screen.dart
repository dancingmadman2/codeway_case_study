import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:codeway_img_proc/app/theme/app_colors.dart';
import 'package:codeway_img_proc/modules/capture/capture_controller.dart';
import 'package:codeway_img_proc/modules/capture/widgets/camera_overlay_painter.dart';
import 'package:codeway_img_proc/shared/widgets/app_loading_indicator.dart';
import 'package:codeway_img_proc/shared/widgets/app_error_view.dart';

class CaptureScreen extends GetView<CaptureController> {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Obx(() {
        return switch (controller.cameraStatus.value) {
          CameraStatus.loading => const AppLoadingIndicator(
              message: 'Initializing camera...',
            ),
          CameraStatus.permissionDenied => AppErrorView(
              icon: Icons.camera_alt,
              message: controller.isPermanentlyDenied
                  ? 'Camera access was denied. Please enable it in Settings.'
                  : 'Camera permission is required to take photos',
              onRetry: controller.isPermanentlyDenied
                  ? () => openAppSettings()
                  : controller.retryCamera,
              retryLabel: controller.isPermanentlyDenied
                  ? 'Open Settings'
                  : 'Allow Camera',
              onBack: () => Get.back(),
            ),
          CameraStatus.error => AppErrorView(
              message: controller.errorMessage.value ?? 'Camera error',
              onRetry: controller.retryCamera,
              onBack: () => Get.back(),
            ),
          CameraStatus.ready => _buildCameraView(context),
        };
      }),
    );
  }

  Widget _buildCameraView(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final localPoint = details.localPosition;
            final normalized = Offset(
              localPoint.dx / box.size.width,
              localPoint.dy / box.size.height,
            );
            controller.setFocusPoint(normalized);
            controller.focusPoint.value = localPoint;
            Future.delayed(const Duration(seconds: 1), () {
              controller.focusPoint.value = null;
            });
          },
          child: controller.cameraController != null
              ? _SafeCameraPreview(controller: controller.cameraController!)
              : const SizedBox.shrink(),
        ),
        Obx(() {
          final point = controller.focusPoint.value;
          if (point == null) return const SizedBox.shrink();
          return Positioned(
            left: point.dx - 30,
            top: point.dy - 30,
            child: const _FocusIndicator(),
          );
        }),
        Obx(() {
          final faces = controller.detectedFaces.value;
          final document = controller.detectedDocument.value;

          if ((faces == null || !faces.hasFaces) &&
              (document == null || !document.hasDocument)) {
            return const SizedBox.shrink();
          }

          final previewSize = controller.cameraController?.value.previewSize;
          if (previewSize == null) return const SizedBox.shrink();

          return CustomPaint(
            painter: CameraOverlayPainter(
              faceResult: faces,
              documentResult: document,
              previewSize: previewSize,
            ),
          );
        }),
        Obx(() {
          final hasDocument =
              controller.detectedDocument.value?.hasDocument == true;
          final isStable = controller.isDocumentStable.value;
          final showHoldSteady =
              (hasDocument && !isStable) || !controller.isDeviceStable.value;
          if (!showHoldSteady) return const SizedBox.shrink();
          return Positioned(
            left: 0,
            right: 0,
            bottom: 140,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Hold steady',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          );
        }),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildBottomBar(),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildGalleryButton(),
            _buildCaptureButton(),
            const SizedBox(width: 56),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryButton() {
    return Material(
      color: AppColors.surfaceVariant.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: controller.pickFromGallery,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(
            CupertinoIcons.photo,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return Obx(() {
      final capturing = controller.isCapturing.value;
      return Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: capturing ? null : controller.captureImage,
          customBorder: const CircleBorder(),
          child: Opacity(
            opacity: capturing ? 0.5 : 1.0,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _FocusIndicator extends StatefulWidget {
  const _FocusIndicator();

  @override
  State<_FocusIndicator> createState() => _FocusIndicatorState();
}

class _FocusIndicatorState extends State<_FocusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.yellow, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SafeCameraPreview extends StatelessWidget {
  const _SafeCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (!value.isInitialized) return const SizedBox.shrink();
        try {
          return controller.buildPreview();
        } on CameraException {
          return const SizedBox.shrink();
        }
      },
    );
  }
}
