import 'package:camera/camera.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription>? _cameras;

  CameraController? get controller => _controller;

  Future<void> initialize() async {
    // FIX: Replaced the 'if' statement with the null-aware assignment operator '??='
    _cameras ??= await availableCameras();
    
    // Use the front camera if available, otherwise the first camera
    CameraDescription cameraDescription = _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );

    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false, // No need for audio in an attendance app
    );

    await _controller?.initialize();
  }

  void dispose() {
    _controller?.dispose();
  }
}