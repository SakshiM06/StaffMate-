import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({super.key});

  // FIX: Renamed the return type from the private _CameraPreviewWidgetState
  // to the now public CameraPreviewWidgetState.
  @override
  CameraPreviewWidgetState createState() => CameraPreviewWidgetState();
}

// FIX: Renamed the class to make it public.
class CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  final CameraService _cameraService = CameraService();
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _cameraService.initialize();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          // If the Future is complete, display the preview.
          return ClipRRect(
            borderRadius: BorderRadius.circular(20.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.green.withValues(alpha: .5),
                  width: 3.0,
                ),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: CameraPreview(_cameraService.controller!),
            ),
          );
        } else {
          // Otherwise, display a loading indicator.
          return const Center(
            child: CircularProgressIndicator(color: Colors.green),
          );
        }
      },
    );
  }
}