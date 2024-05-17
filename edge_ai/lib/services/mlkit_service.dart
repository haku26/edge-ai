import 'package:flutter/rendering.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:edge_ai/models/ocr_text.dart';

class MLKitService {
  final textRecognizer = TextRecognizer();

  Future<List<OcrText>> recognizeText(InputImage inputImage) async {
    final recognizedText = await textRecognizer.processImage(inputImage);

    List<OcrText> ocrTexts = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        ocrTexts.add(OcrText(
          text: line.text,
          rect: Rect.fromLTRB(
            line.boundingBox.left,
            line.boundingBox.top,
            line.boundingBox.right,
            line.boundingBox.bottom,
          ),
        ));
      }
    }
    return ocrTexts;
  }
}
