import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController cameraController;
  final Function(Size) onCameraPreviewSize;

  const CameraPreviewWidget(
      {super.key,
      required this.cameraController,
      required this.onCameraPreviewSize});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // CameraPreviewのサイズを取得
        final previewSize = Size(constraints.maxWidth, constraints.maxHeight);
        onCameraPreviewSize(previewSize);

        return CameraPreview(cameraController);
      },
    );
  }
}
