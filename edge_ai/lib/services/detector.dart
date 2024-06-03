import 'dart:async';
import 'package:camera/camera.dart';

abstract class Detector {
  Stream<Map<String, dynamic>> get resultsStream;
  static Future<Detector?> start() async {
    return null;
  }

  void stop();
  void processFrame(CameraImage cameraImage);
}

/// A command sent between [ObjectDetector] and [_DetectorServer].
class DetectCommand {
  const DetectCommand(this.code, {this.args});

  final DetectServerCodes code;
  final List<Object>? args;
}

/// All the command codes that can be sent and received between [ObjectDetector] and
/// All the command codes that can be sent and received between [ObjectDetector] and
/// [_DetectorServer].
enum DetectServerCodes {
  init,
  busy,
  ready,
  detect,
  result,
}
