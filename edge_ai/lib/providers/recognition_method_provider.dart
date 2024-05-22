import 'package:hooks_riverpod/hooks_riverpod.dart';

enum RecognitionMethod {
  mlkit,
  tflite,
}

final recognitionMethodProvider =
    StateProvider<RecognitionMethod>((ref) => RecognitionMethod.mlkit);
