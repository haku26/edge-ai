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
    ref.read(detectorProvider.notifier).setObjectDetector();

    useEffect(() {
      WidgetsBinding.instance.addObserver(_AppLifecycleObserver(ref));
      ref.read(cameraControllerProvider.notifier).initializeCamera();
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
    // 任意の幅
    // var width = MediaQuery.sizeOf(context).width;
    // var height = MediaQuery.sizeOf(context).height;
    var width = cameraController.value.previewSize?.width;
    var height = cameraController.value.previewSize?.height;

    return Stack(
      children: [
        Center(
          child: SizedBox(
            width: width,
            height: height,
            child: AspectRatio(
              aspectRatio: aspect,
              child: CameraPreview(cameraController),
            ),
          ),
        ),
        Center(
          child: SizedBox(
            width: width, // 任意の幅
            height: height, // 任意の高さ
            child: AspectRatio(
              aspectRatio: aspect,
              child: _boundingBoxes(recognitions),
            ),
          ),
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
        // 非同期処理でObjectDetectorを作成し、開始する
        ref.read(detectorProvider.notifier).start();
        break;
      default:
    }
  }
}
