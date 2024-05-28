import 'package:camera/camera.dart';
import 'package:edge_ai/models/screen_params.dart';
import 'package:edge_ai/providers/detector_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final cameraControllerProvider =
    NotifierProvider<CameraControllerNotifier, CameraController?>(
        CameraControllerNotifier.new);

final cameraInitializationStatusProvider = StateProvider<bool>((ref) {
  return false;
});

class CameraControllerNotifier extends Notifier<CameraController?> {
  @override
  CameraController? build() {
    return null; // 初期状態としてnullを設定
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final camera = cameras.first;

    state = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await state?.initialize();
    if (state != null && state!.value.isInitialized) {
      ScreenParams.previewSize = state!.value.previewSize!;
    }

    ref.read(cameraInitializationStatusProvider.notifier).state = true;

    // Start the image stream
    await startImageStream();
  }

  Future<void> startImageStream() async {
    if (state != null && state!.value.isInitialized) {
      await state!.startImageStream((CameraImage image) {
        ref.read(detectorProvider)?.processFrame(image);
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

  void dispose() {
    state?.dispose();
  }
}
