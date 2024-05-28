import 'dart:async';
import 'package:edge_ai/models/recognition.dart';
import 'package:edge_ai/services/object_detector_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final detectorProvider =
    NotifierProvider<DetectorNotifier, ObjectDetector?>(DetectorNotifier.new);

final recognitionProvider = StateProvider<List<Recognition>?>((ref) => null);

final statsProvider = StateProvider<Map<String, String>?>((ref) => null);

class DetectorNotifier extends Notifier<ObjectDetector?> {
  StreamSubscription? _subscription;

  @override
  ObjectDetector? build() {
    return null;
  }

  Future<void> start() async {
    state = await ObjectDetector.start();
    _subscription = state!.resultsStream.stream.listen((values) {
      ref.read(recognitionProvider.notifier).state = values['recognitions'];
      ref.read(statsProvider.notifier).state = values['stats'];
    });
  }

  void stop() {
    state?.stop();
    _subscription?.cancel();
  }
}
