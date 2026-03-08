import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:codeway_img_proc/data/services/camera_service.dart';
import 'package:codeway_img_proc/data/services/document_detection_service.dart';
import 'package:codeway_img_proc/data/services/face_detection_service.dart';
import 'package:codeway_img_proc/domain/models/document_detection_result.dart';
import 'package:codeway_img_proc/domain/models/face_detection_result.dart';
import 'package:codeway_img_proc/app/routes/app_routes.dart';
import 'package:codeway_img_proc/app/routes/route_arguments.dart';
import 'package:codeway_img_proc/domain/models/processing_type.dart';
import 'package:codeway_img_proc/shared/utils/corner_smoother.dart';
import 'package:codeway_img_proc/shared/utils/snackbar_utils.dart';

enum CameraStatus { loading, ready, permissionDenied, error }

class CaptureController extends GetxController with WidgetsBindingObserver {
  final _cameraService = Get.find<CameraService>();
  final _faceDetectionService = Get.find<FaceDetectionService>();
  final _documentDetectionService = Get.find<DocumentDetectionService>();
  final _picker = ImagePicker();

  final cameraStatus = CameraStatus.loading.obs;
  final errorMessage = Rxn<String>();
  final isProcessingFrame = false.obs;
  final detectedFaces = Rxn<FaceDetectionResult>();
  final detectedDocument = Rxn<LiveDocumentResult>();
  final isDocumentStable = false.obs;
  final isCapturing = false.obs;
  final focusPoint = Rxn<Offset>();
  final isDeviceStable = true.obs;
  final _permanentlyDenied = false.obs;
  final _cornerSmoother = CornerSmoother();
  int _noEdgeFrameCount = 0;
  static const int _holdOverFrames = 10;
  StreamSubscription? _gyroSubscription;
  DateTime? _lastUnstableTime;
  CameraController? get cameraController => _cameraService.controller;
  bool get isPermanentlyDenied => _permanentlyDenied.value;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Defer camera init so the route transition animation isn't janked
    Future.delayed(const Duration(milliseconds: 300), _initCamera);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        cameraStatus.value == CameraStatus.permissionDenied) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      cameraStatus.value = CameraStatus.loading;
      errorMessage.value = null;

      final status = await Permission.camera.request();

      if (status.isGranted || status.isLimited) {
        await _cameraService.initialize(onFrame: _onCameraFrame);
        if (_cameraService.isInitialized) {
          cameraStatus.value = CameraStatus.ready;
          _startMotionMonitoring();
        } else {
          errorMessage.value = 'No camera available';
          cameraStatus.value = CameraStatus.error;
        }
      } else if (status.isPermanentlyDenied) {
        _permanentlyDenied.value = true;
        cameraStatus.value = CameraStatus.permissionDenied;
      } else {
        _permanentlyDenied.value = false;
        cameraStatus.value = CameraStatus.permissionDenied;
      }
    } catch (e) {
      errorMessage.value = 'Failed to initialize camera';
      cameraStatus.value = CameraStatus.error;
    }
  }

  Future<void> retryCamera() => _initCamera();

  void _onCameraFrame(CameraImage image) {
    if (isProcessingFrame.value) return;
    isProcessingFrame.value = true;

    _processFrame(image).whenComplete(() {
      isProcessingFrame.value = false;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) return;

      // Always try face detection first (fast, ~15ms)
      final faceResult = await _faceDetectionService.detectFaces(inputImage);
      detectedFaces.value = faceResult;

      if (faceResult.hasFaces) {
        // Face found — clear any document overlay
        detectedDocument.value = null;
        _cornerSmoother.reset();
        isDocumentStable.value = false;
      } else {
        // No faces — try document detection via ML Kit text recognition
        final sensorOrientation =
            _cameraService.controller!.description.sensorOrientation;
        final docResult = await _documentDetectionService.detectDocumentFast(
          inputImage,
          image,
          defaultTargetPlatform,
          sensorOrientation,
        );

        // Apply temporal smoothing with hold-over logic
        if (docResult.hasDocument) {
          _noEdgeFrameCount = 0;
          final smoothedResult = _cornerSmoother.smoothResult(docResult);
          detectedDocument.value = smoothedResult;
          isDocumentStable.value = _cornerSmoother.isStable;
        } else {
          _noEdgeFrameCount++;
          if (_noEdgeFrameCount < _holdOverFrames &&
              detectedDocument.value?.hasDocument == true) {
            // Keep showing last good detection
            return;
          }
          _noEdgeFrameCount = 0;
          _cornerSmoother.reset();
          isDocumentStable.value = false;
          detectedDocument.value = docResult;
        }
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameraService.controller;
    if (camera == null) return null;

    final sensorOrientation = camera.description.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> setFocusPoint(Offset normalizedPoint) async {
    try {
      await _cameraService.controller?.setFocusPoint(normalizedPoint);
      await _cameraService.controller?.setExposurePoint(normalizedPoint);
      await _cameraService.controller?.setFocusMode(FocusMode.auto);
    } catch (_) {}
  }

  void _startMotionMonitoring() {
    _gyroSubscription?.cancel();
    _gyroSubscription = gyroscopeEventStream(
      samplingPeriod: const Duration(milliseconds: 100),
    ).listen((event) {
      final magnitude =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > 0.3) {
        _lastUnstableTime = DateTime.now();
        if (isDeviceStable.value) isDeviceStable.value = false;
      } else {
        final lastUnstable = _lastUnstableTime;
        if (lastUnstable != null &&
            DateTime.now().difference(lastUnstable).inMilliseconds > 300) {
          if (!isDeviceStable.value) isDeviceStable.value = true;
        } else if (lastUnstable == null) {
          isDeviceStable.value = true;
        }
      }
    });
  }

  Future<void> captureImage() async {
    if (isCapturing.value) return;
    isCapturing.value = true;
    try {
      final hasFaces = detectedFaces.value?.hasFaces == true;
      final hasDocument = detectedDocument.value?.hasDocument == true
          || (detectedDocument.value?.textBlocks.isNotEmpty ?? false);

      cameraStatus.value = CameraStatus.loading;

      Get.toNamed(
        AppRoutes.processing,
        arguments: ProcessingArgs(
          null,
          detectedType: hasFaces
              ? ProcessingType.face
              : hasDocument
                  ? ProcessingType.document
                  : null,
        ),
      );
    } catch (e) {
      cameraStatus.value = CameraStatus.ready;
      showAppSnackbar('Error', 'Failed to start capture');
    } finally {
      isCapturing.value = false;
    }
  }

  Future<void> pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final file = File(picked.path);
      if (!await file.exists() || await file.length() == 0) {
        showAppSnackbar('Error', 'The selected image could not be read.');
        return;
      }

      Get.toNamed(AppRoutes.processing, arguments: ProcessingArgs(picked.path));
    } catch (e) {
      showAppSnackbar('Error', 'Failed to pick image from gallery.');
    }
  }

  @override
  void onClose() {
    _gyroSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    cameraStatus.value = CameraStatus.loading;
    _cameraService.dispose();
    _faceDetectionService.dispose();
    _documentDetectionService.dispose();
    super.onClose();
  }
}
