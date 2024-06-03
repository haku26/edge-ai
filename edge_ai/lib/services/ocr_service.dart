import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:edge_ai/services/detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:edge_ai/models/recognition.dart';
import 'package:edge_ai/utils/image_utils.dart';
import 'package:opencv_dart/opencv_dart.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// All the heavy operations like pre-processing, detection, ets,
/// are executed in a background isolate.
/// This class just sends and receives messages to the isolate.
class OcrService implements Detector {
  static const String _textDetectorModelPath =
      'assets/models/east-text-detector-fp16.tflite';
  static const String _ocrModelPath = 'assets/models/keras-ocr-fp16.tflite';
  static const String _ocrLabelPath = 'assets/labels/ocr-label.txt';
  static const int detectionOutputNumRows = 80;
  static const int detectionOutputNumCols = 80;
  static const int detectionOutputDepth = 5;

  OcrService._(this._isolate, this._detector, this._recognizer, this._labels);

  Isolate _isolate;
  late final Interpreter _detector;
  late final Interpreter _recognizer;
  late final List<String> _labels;

  // To be used by detector (from UI) to send message to our Service ReceivePort
  late final SendPort _sendPort;

  bool _isReady = false;

  // // Similarly, StreamControllers are stored in a queue so they can be handled
  // // asynchronously and serially.
  final StreamController<Map<String, dynamic>> _resultsStreamController =
      StreamController<Map<String, dynamic>>();

  @override
  Stream<Map<String, dynamic>> get resultsStream =>
      _resultsStreamController.stream;

  static Future<Detector?> start() async {
    final ReceivePort receivePort = ReceivePort();
    // sendPort - To be used by service Isolate to send message to our ReceiverPort
    final Isolate isolate =
        await Isolate.spawn(_DetectorServer._run, receivePort.sendPort);

    final OcrService result = OcrService._(
      isolate,
      await _loadDetectorModel(),
      await _loadOcrModel(),
      await _loadLabels(),
    );
    receivePort.listen((message) {
      result.handleCommand(message as DetectCommand);
    });
    return result;
  }

  static Future<Interpreter> _loadDetectorModel() async {
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      //interpreterOptions.addDelegate(XNNPackDelegate());
      interpreterOptions.addDelegate(GpuDelegateV2());
    }

    return Interpreter.fromAsset(
      _textDetectorModelPath,
      options: interpreterOptions..threads = 4,
    );
  }

  static Future<Interpreter> _loadOcrModel() async {
    final interpreterOptions = InterpreterOptions();

    // Use XNNPACK Delegate
    if (Platform.isAndroid) {
      interpreterOptions.addDelegate(XNNPackDelegate());
    }

    return Interpreter.fromAsset(
      _ocrModelPath,
      options: interpreterOptions..threads = 4,
    );
  }

  static Future<List<String>> _loadLabels() async {
    return (await rootBundle.loadString(_ocrLabelPath)).split('\n');
  }

  /// Starts CameraImage processing
  void processFrame(CameraImage cameraImage) {
    if (_isReady) {
      _sendPort
          .send(DetectCommand(DetectServerCodes.detect, args: [cameraImage]));
    }
  }

  /// Handler invoked when a message is received from the port communicating
  /// with the database server.
  @override
  void handleCommand(DetectCommand command) {
    switch (command.code) {
      case DetectServerCodes.init:
        _sendPort = command.args?[0] as SendPort;
        // ----------------------------------------------------------------------
        // Before using platform channels and plugins from background isolates we
        // need to register it with its root isolate. This is achieved by
        // acquiring a [RootIsolateToken] which the background isolate uses to
        // invoke [BackgroundIsolateBinaryMessenger.ensureInitialized].
        // ----------------------------------------------------------------------
        RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;
        _sendPort.send(DetectCommand(DetectServerCodes.init, args: [
          rootIsolateToken,
          _detector.address,
          _recognizer.address,
          _labels,
        ]));
      case DetectServerCodes.ready:
        _isReady = true;
      case DetectServerCodes.busy:
        _isReady = false;
      case DetectServerCodes.result:
        _isReady = true;
        _resultsStreamController.add(command.args?[0] as Map<String, dynamic>);
      default:
        debugPrint('Detector unrecognized command: ${command.code}');
    }
  }

  /// Kills the background isolate and its detector server.
  void stop() {
    _isolate.kill();
  }
}

/// The portion of the [ObjectDetector] that runs on the background isolate.
///
/// This is where we use the new feature Background Isolate Channels, which
/// allows us to use plugins from background isolates.
class _DetectorServer {
  /// Input size of image (height = width = 320)
  static const int detectorModelInputSize = 320;

  static const int detectionOutputNumRows = 80;
  static const int detectionOutputNumCols = 80;
  static const int detectionOutputDepth = 5;

  /// Result confidence threshold
  static const double confidence = 0.5;
  Interpreter? _detector;
  Interpreter? _recognizer;
  List<String>? _labels;

  _DetectorServer(this._sendPort);

  final SendPort _sendPort;

  // ----------------------------------------------------------------------
  // Here the plugin is used from the background isolate.
  // ----------------------------------------------------------------------

  /// The main entrypoint for the background isolate sent to [Isolate.spawn].
  static void _run(SendPort sendPort) {
    ReceivePort receivePort = ReceivePort();
    final _DetectorServer server = _DetectorServer(sendPort);
    receivePort.listen((message) async {
      final DetectCommand command = message as DetectCommand;
      await server._handleCommand(command);
    });
    // receivePort.sendPort - used by UI isolate to send commands to the service receiverPort
    sendPort.send(
        DetectCommand(DetectServerCodes.init, args: [receivePort.sendPort]));
  }

  /// Handle the [command] received from the [ReceivePort].
  Future<void> _handleCommand(DetectCommand command) async {
    switch (command.code) {
      case DetectServerCodes.init:
        // ----------------------------------------------------------------------
        // The [RootIsolateToken] is required for
        // [BackgroundIsolateBinaryMessenger.ensureInitialized] and must be
        // obtained on the root isolate and passed into the background isolate via
        // a [SendPort].
        // ----------------------------------------------------------------------
        RootIsolateToken rootIsolateToken =
            command.args?[0] as RootIsolateToken;
        // ----------------------------------------------------------------------
        // [BackgroundIsolateBinaryMessenger.ensureInitialized] for each
        // background isolate that will use plugins. This sets up the
        // [BinaryMessenger] that the Platform Channels will communicate with on
        // the background isolate.
        // ----------------------------------------------------------------------
        BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
        _detector = Interpreter.fromAddress(command.args?[1] as int);
        _recognizer = Interpreter.fromAddress(command.args?[2] as int);
        _labels = command.args?[3] as List<String>;
        _sendPort.send(const DetectCommand(DetectServerCodes.ready));
      case DetectServerCodes.detect:
        _sendPort.send(const DetectCommand(DetectServerCodes.busy));
        _convertCameraImage(command.args?[0] as CameraImage);
      default:
        debugPrint('_DetectorService unrecognized command ${command.code}');
    }
  }

  void _convertCameraImage(CameraImage cameraImage) {
    var preConversionTime = DateTime.now().millisecondsSinceEpoch;

    convertCameraImageToImage(cameraImage).then((image) {
      if (image != null) {
        if (Platform.isAndroid) {
          image = image_lib.copyRotate(image, angle: 90);
        }

        final results = analyseImage(image, preConversionTime);
        _sendPort
            .send(DetectCommand(DetectServerCodes.result, args: [results]));
      }
    });
  }

  Map<String, dynamic> analyseImage(
      image_lib.Image? image, int preConversionTime) {
    var conversionElapsedTime =
        DateTime.now().millisecondsSinceEpoch - preConversionTime;

    var preProcessStart = DateTime.now().millisecondsSinceEpoch;

    /// Pre-process the image
    /// Resizing image for model [320, 320]
    final imageInput = image_lib.copyResize(
      image!,
      width: detectorModelInputSize,
      height: detectorModelInputSize,
    );

    // Creating matrix representation, [320, 320, 3]
    final imageMatrix = List.generate(
      imageInput.height,
      (y) => List.generate(
        imageInput.width,
        (x) {
          final pixel = imageInput.getPixel(x, y);
          return [pixel.r, pixel.g, pixel.b];
        },
      ),
    );

    var preProcessElapsedTime =
        DateTime.now().millisecondsSinceEpoch - preProcessStart;

    var inferenceTimeStart = DateTime.now().millisecondsSinceEpoch;

    final output = _runDetection(imageMatrix);

    //final output = {
    //  0: [List<List<num>>.filled(10, List<num>.filled(4, 0))],
    //  1: [List<num>.filled(10, 0)],
    //  2: [List<num>.filled(10, 0)],
    //  3: [0.0],
    //};
    // Location
    final detectionScores = output[0] as List<List<List<List<double>>>>;
    final detectionGeometries =
        output[1].first as List<List<List<List<double>>>>;

    // Transposing detection output tensors
    var transposeddetectionScores = List.generate(
        1,
        (_) => List.generate(
            1,
            (_) => List.generate(detectionOutputNumRows,
                (_) => List.filled(detectionOutputNumCols, 0.0))));
    var transposedDetectionGeometries = List.generate(
        1,
        (_) => List.generate(
            5,
            (_) => List.generate(detectionOutputNumRows,
                (_) => List.filled(detectionOutputNumCols, 0.0))));

    for (var i = 0; i < transposeddetectionScores[0][0].length; i++) {
      for (var j = 0; j < transposeddetectionScores[0][0][0].length; j++) {
        for (var k = 0; k < 1; k++) {
          transposeddetectionScores[0][k][i][j] = detectionScores[0][i][j][k];
        }
        for (var k = 0; k < 5; k++) {
          transposedDetectionGeometries[0][k][i][j] =
              detectionGeometries[0][i][j][k];
        }
      }
    }

    // Detection results
    var detectedRotatedRects = [];
    List<double> detectedConfidences = [];

    for (var y = 0; y < transposeddetectionScores[0][0].length; y++) {
      List<double> detectionScoreData = transposeddetectionScores[0][0][y];
      var detectionGeometryX0Data = transposedDetectionGeometries[0][0][y];
      var detectionGeometryX1Data = transposedDetectionGeometries[0][1][y];
      var detectionGeometryX2Data = transposedDetectionGeometries[0][2][y];
      var detectionGeometryX3Data = transposedDetectionGeometries[0][3][y];
      var detectionRotationAngleData = transposedDetectionGeometries[0][4][y];

      for (var x = 0; x < transposeddetectionScores[0][0][0].length; x++) {
        if (detectionScoreData[x] < 0.5) {
          continue;
        }

        // Compute the rotated bounding boxes and confidences (based on OpenCV example)
        var offsetX = x * 4.0;
        var offsetY = y * 4.0;

        var h = detectionGeometryX0Data[x] + detectionGeometryX2Data[x];
        var w = detectionGeometryX1Data[x] + detectionGeometryX3Data[x];

        var angle = detectionRotationAngleData[x];
        var cosine = cos(angle);
        var sine = sin(angle);

        var offset = Point2f(
            offsetX +
                cosine * detectionGeometryX1Data[x] +
                sine * detectionGeometryX2Data[x],
            offsetY -
                sine * detectionGeometryX1Data[x] +
                cosine * detectionGeometryX2Data[x]);
        var p1 = Point2f(-sine * h + offset.x, -cosine * h + offset.y);
        var p3 = Point2f(-cosine * w + offset.x, sine * w + offset.y);
        var center = Point2f(0.5 * (p1.x + p3.x), 0.5 * (p1.y + p3.y));

        var textDetection =
            RotatedRect(center, (w, h), (-1 * angle * 180.0 / pi));
        detectedRotatedRects.add(textDetection);
        detectedConfidences.add(detectionScoreData[x]);
      }
    }

    // -------
    // var detectedConfidencesMat = vectorFloatToMat(detectedConfidences);
    //val detectedConfidencesMat = MatOfFloat(vector_float_to_Mat(detectedConfidences))

    //boundingBoxesMat = MatOfRotatedRect(vector_RotatedRect_to_Mat(detectedRotatedRects))
    //NMSBoxesRotated(
    //  boundingBoxesMat,
    //  detectedConfidencesMat,
    //  detectionConfidenceThreshold.toFloat(),
    //  detectionNMSThreshold.toFloat(),
    //  indicesMat
    //)

    // Location
    final locationsRaw = output.first.first as List<List<double>>;
    final List<ui.Rect> locations = locationsRaw
        .map((list) =>
            list.map((value) => (value * detectorModelInputSize)).toList())
        .map((rect) => ui.Rect.fromLTRB(rect[1], rect[0], rect[3], rect[2]))
        .toList();

    // Classes
    final classesRaw = output.elementAt(1).first as List<double>;
    final classes = classesRaw.map((value) => value.toInt()).toList();

    // Scores
    final scores = output.elementAt(2).first as List<double>;

    // Number of detections
    final numberOfDetectionsRaw = output.last.first as double;
    final numberOfDetections = numberOfDetectionsRaw.toInt();

    final List<String> classification = [];
    for (var i = 0; i < numberOfDetections; i++) {
      classification.add(_labels![classes[i]]);
    }

    /// Generate recognitions
    List<Recognition> recognitions = [];
    for (int i = 0; i < numberOfDetections; i++) {
      // Prediction score
      var score = scores[i];
      // Label string
      var label = classification[i];

      if (score > confidence) {
        recognitions.add(
          Recognition(i, label, score, locations[i]),
        );
      }
    }

    var inferenceElapsedTime =
        DateTime.now().millisecondsSinceEpoch - inferenceTimeStart;

    var totalElapsedTime =
        DateTime.now().millisecondsSinceEpoch - preConversionTime;

    return {
      "recognitions": recognitions,
      "stats": <String, String>{
        'Conversion time:': conversionElapsedTime.toString(),
        'Pre-processing time:': preProcessElapsedTime.toString(),
        'Inference time:': inferenceElapsedTime.toString(),
        'Total prediction time:': totalElapsedTime.toString(),
        'Frame': '${image.width} X ${image.height}',
      },
    };
  }

  /// Object detection main function
  List<List> _runDetection(
    List<List<List<num>>> imageMatrix,
  ) {
    // Set input tensor [1, 300, 300, 3]
    final input = [imageMatrix];

    // Creating detection scores tensor of shape (1, 80, 80, 5)
    List<List<List<List<double>>>> detectionScores = List.generate(
      1,
      (_) => List.generate(
        detectionOutputNumRows,
        (_) => List.generate(
          detectionOutputNumCols,
          (_) => List.filled(detectionOutputDepth, 0.0),
        ),
      ),
    );

    // Creating detection geometries tensor of shape (1, 80, 80, 5)
    List<List<List<List<double>>>> detectionGeometries = List.generate(
      1,
      (_) => List.generate(
        detectionOutputNumRows,
        (_) => List.generate(
          detectionOutputNumCols,
          (_) => List.filled(detectionOutputDepth, 0.0),
        ),
      ),
    );

    Map<int, List<List<List<List<double>>>>> detectionOutputs = {};
    detectionOutputs[0] = detectionScores;
    detectionOutputs[1] = detectionGeometries;

    _detector!.runForMultipleInputs([input], detectionOutputs);
    return detectionOutputs.values.toList();
  }

  Mat vectorFloatToMat(List<List<double>> vector) {
    // Create a Mat with the appropriate size and type
    int rows = vector.length;
    int cols = vector[0].length;
    Mat mat = Mat.zeros(rows, cols, MatType.CV_32FC2);

    // Fill the Mat with the data from the vector
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < cols; j++) {
        mat.set(i, j, vector[i][j]);
      }
    }

    return mat;
  }
}
