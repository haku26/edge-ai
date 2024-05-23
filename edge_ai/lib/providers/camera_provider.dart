import 'package:camera/camera.dart';
import 'package:edge_ai/models/screen_params.dart';
import 'package:edge_ai/services/image_processor_service.dart';
import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final cameraControllerProvider =
    StateNotifierProvider<CameraControllerNotifier, CameraController?>((ref) {
  return CameraControllerNotifier(ref);
});

final cameraInitializationStatusProvider = StateProvider<bool>((ref) {
  return false;
});

class CameraControllerNotifier extends StateNotifier<CameraController?> {
  final Ref ref;

  CameraControllerNotifier(this.ref) : super(null);

  Future<void> initializeCamera(context) async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    state = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await state?.initialize();
    if (state != null && state!.value.isInitialized) {
      ScreenParams.initialize(
        MediaQuery.of(context).size,
        state!.value.previewSize!,
      );
    }

    ref.read(cameraInitializationStatusProvider.notifier).state = true;

    // Start the image stream
    await startImageStream();

    ScreenParams.previewSize = state!.value.previewSize!;
  }

  Future<void> startImageStream() async {
    if (state != null && state!.value.isInitialized) {
      await state!.startImageStream((CameraImage image) {
        ref.read(imageStreamProvider.notifier).update(image);
        ref.read(imageProcessorProvider).processImage(image);
      });
    }
  }

  Future<void> stopImageStream() async {
    if (state != null &&
        state!.value.isInitialized &&
        state!.value.isStreamingImages) {
      await state!.stopImageStream();
    }
  }

  @override
  void dispose() {
    state?.dispose();
    super.dispose();
  }
}

final imageStreamProvider =
    StateNotifierProvider<ImageStreamNotifier, CameraImage?>((ref) {
  return ImageStreamNotifier();
});

class ImageStreamNotifier extends StateNotifier<CameraImage?> {
  ImageStreamNotifier() : super(null);

  void update(CameraImage image) {
    state = image;
  }
}
