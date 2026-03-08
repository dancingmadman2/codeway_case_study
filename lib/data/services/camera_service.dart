import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  CameraController? get controller => _controller;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  /// Pre-cache the camera list so initialize() is faster.
  Future<void> warmUp() async {
    _cameras ??= await availableCameras();
  }

  Future<void> initialize({
    ResolutionPreset resolution = ResolutionPreset.high,
    Function(CameraImage)? onFrame,
  }) async {
    _cameras ??= await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    final backCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(backCamera, resolution, enableAudio: false);
    await _controller!.initialize();

    // Enable continuous auto-focus and auto-exposure from the start
    try {
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (_) {}

    if (onFrame != null) {
      await _controller!.startImageStream(onFrame);
    }
  }

  Future<String?> takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return null;

    // Stop image stream if running (required on Android)
    try {
      await _controller!.stopImageStream();
    } catch (_) {}

    // Lock focus & exposure so they don't shift during capture
    try {
      await _controller!.setFocusMode(FocusMode.locked);
      await _controller!.setExposureMode(ExposureMode.locked);
    } catch (_) {
      // Some devices/cameras don't support locking — proceed anyway
    }

    // Brief settle time for the lock to take effect
    await Future.delayed(const Duration(milliseconds: 400));

    final xFile = await _controller!.takePicture();

    // Restore continuous auto modes
    try {
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (_) {}

    return xFile.path;
  }

  /// Reinitialize at max resolution, capture, and return the image path.
  /// Caller navigates away after — no need to restore preview resolution.
  Future<String?> captureAtMaxResolution() async {
    if (_cameras == null || _cameras!.isEmpty) return null;

    // Stop image stream before disposing to prevent race with frame callbacks
    try {
      await _controller?.stopImageStream();
    } catch (_) {}

    await _controller?.dispose();
    _controller = null;

    final backCamera = _cameras!.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      backCamera,
      ResolutionPreset.max,
      enableAudio: false,
    );
    await _controller!.initialize();

    // Let auto-focus acquire on the scene (~500ms)
    try {
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));

    // Lock focus & exposure so they don't shift during capture
    try {
      await _controller!.setFocusMode(FocusMode.locked);
      await _controller!.setExposureMode(ExposureMode.locked);
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));

    final xFile = await _controller!.takePicture();
    return xFile.path;
  }

  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
