import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:edge_ai/providers/ocr_provider.dart';
import 'package:edge_ai/services/mlkit_service.dart';
import 'package:edge_ai/widgets/camera_preview_widget.dart';
import 'package:edge_ai/widgets/ocr_text_overlay_widget.dart';

class CameraView extends ConsumerStatefulWidget {
  const CameraView({super.key});

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends ConsumerState<CameraView> {
  CameraController? _cameraController;
  late MLKitService _mlKitService;

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _mlKitService = MLKitService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController?.initialize();
    if (!mounted) return;

    _cameraController?.startImageStream((CameraImage image) async {
      final inputImage = _convertCameraImage(image);
      final ocrTexts = await _mlKitService.recognizeText(inputImage!);
      ref.read(ocrTextProvider.state).state = ocrTexts;
    });

    setState(() {});
  }

  InputImage? _convertCameraImage(CameraImage image) {
    if (_cameraController == null) return null;

    // Get the image rotation
    final camera = _cameraController?.description;
    final sensorOrientation = camera?.sensorOrientation;
    InputImageRotation rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation!)!;
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_cameraController!.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera?.lensDirection == CameraLensDirection.front) {
        // Front-facing camera
        rotationCompensation =
            (sensorOrientation! + rotationCompensation) % 360;
      } else {
        // Back-facing camera
        rotationCompensation =
            (sensorOrientation! - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation)!;
    } else {
      return null;
    }

    // Get the image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Prepare input image metadata
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    // Create InputImage
    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: metadata,
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: Stack(
        children: [
          CameraPreviewWidget(cameraController: _cameraController!),
          Consumer(
            builder: (context, watch, child) {
              final ocrTexts = ref.watch(ocrTextProvider);
              return OcrTextOverlayWidget(ocrTexts: ocrTexts);
            },
          ),
        ],
      ),
    );
  }
}
