import 'package:camera/camera.dart';
import 'package:edge_ai/models/screen_params.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:edge_ai/models/recognition.dart';
import 'package:edge_ai/providers/camera_provider.dart';
import 'package:edge_ai/providers/detector_provider.dart';
import 'package:edge_ai/widgets/box_widget.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DetectorWidget extends HookConsumerWidget {
  const DetectorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ScreenParams.screenSize = MediaQuery.sizeOf(context);
    final cameraController = ref.watch(cameraControllerProvider);
    final recognitions = ref.watch(recognitionProvider);
    final isCameraInitialized = ref.watch(cameraInitializationStatusProvider);

    useEffect(() {
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver(ref));
      ref.read(cameraControllerProvider.notifier).initializeCamera(context);
      ref.read(detectorProvider.notifier).start();
      return () {
        WidgetsBinding.instance.removeObserver(_AppLifecycleObserver(ref));
        ref.read(detectorProvider.notifier).stop();
        ref.read(cameraControllerProvider.notifier).dispose();
      };
    }, []);

    if (!isCameraInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    var aspect = 1 / cameraController.value.aspectRatio;

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: aspect,
          child: CameraPreview(cameraController),
        ),
        AspectRatio(
          aspectRatio: aspect,
          child: _boundingBoxes(recognitions),
        ),
      ],
    );
  }

  Widget _boundingBoxes(List<Recognition>? results) {
    if (results == null) {
      return const SizedBox.shrink();
    }
    return Stack(
        children: results.map((box) => BoxWidget(result: box)).toList());
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  final WidgetRef ref;

  _AppLifecycleObserver(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        ref.read(cameraControllerProvider.notifier).stopImageStream();
        ref.read(detectorProvider.notifier).stop();
        break;
      case AppLifecycleState.resumed:
        ref.read(cameraControllerProvider.notifier).startImageStream();
        ref.read(detectorProvider.notifier).start();
        break;
      default:
    }
  }
}
