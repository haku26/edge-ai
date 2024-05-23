import 'package:edge_ai/providers/detector_provider.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'detector_service.dart';
import 'package:camera/camera.dart';

final imageProcessorProvider = Provider<ImageProcessorService>((ref) {
  final detector = ref.watch(detectorProvider);
  return ImageProcessorService(detector!);
});

class ImageProcessorService {
  ImageProcessorService(this.detector);

  final Detector detector;

  void processImage(CameraImage cameraImage) {
    // Detectorで処理
    detector.processFrame(cameraImage);
  }
}
