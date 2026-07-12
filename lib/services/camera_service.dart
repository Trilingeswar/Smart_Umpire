import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;

  // Initialize camera
  Future<void> initializeCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use first camera (usually laptop's integrated camera)
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false, // No audio as per requirements
      );

      await _controller!.initialize();
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize camera: $e');
    }
  }

  // Dispose camera
  Future<void> dispose() async {
    await _controller?.dispose();
    _isInitialized = false;
  }

  // Get available cameras
  Future<List<CameraDescription>> getAvailableCameras() async {
    if (_cameras == null) {
      _cameras = await availableCameras();
    }
    return _cameras!;
  }

  // Switch camera (if multiple cameras available)
  Future<void> switchCamera(int cameraIndex) async {
    if (_cameras == null || cameraIndex >= _cameras!.length) {
      throw Exception('Invalid camera index');
    }

    await _controller?.dispose();

    _controller = CameraController(
      _cameras![cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
  }
}
