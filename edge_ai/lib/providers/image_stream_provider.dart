import 'package:camera/camera.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
