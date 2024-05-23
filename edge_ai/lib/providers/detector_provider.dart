import 'dart:async';
import 'package:edge_ai/models/recognition.dart';
import 'package:edge_ai/services/detector_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final detectorProvider =
    NotifierProvider<DetectorNotifier, Detector?>(DetectorNotifier.new);

final recognitionProvider = StateProvider<List<Recognition>?>((ref) => null);

final statsProvider = StateProvider<Map<String, String>?>((ref) => null);

class DetectorNotifier extends Notifier<Detector?> {
  StreamSubscription? _subscription;

  @override
  Detector? build() {
    return null;
  }

  Future<void> start() async {
    state = await Detector.start();
    _subscription = state!.resultsStream.stream.listen((values) {
      ref.read(recognitionProvider.notifier).state = values['recognitions'];
      ref.read(statsProvider.notifier).state = values['stats'];
    });
  }

  void stop() {
    state?.stop();
    _subscription?.cancel();
  }

  void dispose() {
    stop();
  }
}
