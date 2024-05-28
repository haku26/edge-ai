import 'dart:async';
import 'package:camera/camera.dart';
import 'package:edge_ai/models/recognition.dart';
import 'package:edge_ai/services/detector.dart';
import 'package:edge_ai/services/object_detector_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final recognitionProvider = StateProvider<List<Recognition>?>((ref) => null);

final statsProvider = StateProvider<Map<String, String>?>((ref) => null);

final detectorProvider = NotifierProvider<DetectorNotifier, Detector?>(
  DetectorNotifier.new,
);

class DetectorNotifier extends Notifier<Detector?> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  @override
  Detector? build() {
    return null;
  }

  Future<void> start() async {
    state = await Detector.start();
    _subscription = state?.resultsStream.listen((values) {
      ref.read(recognitionProvider.notifier).state = values['recognitions'];
      ref.read(statsProvider.notifier).state = values['stats'];
    });
  }

  void processFrame(CameraImage cameraImage) {
    state?.processFrame(cameraImage);
  }

  void stop() {
    state?.stop();
    _subscription?.cancel();
  }

  Future<void> setObjectDetector() async {
    state = await ObjectDetector.start();
    _subscription = state?.resultsStream.listen((values) {
      ref.read(recognitionProvider.notifier).state = values['recognitions'];
      ref.read(statsProvider.notifier).state = values['stats'];
    });
  }
}
