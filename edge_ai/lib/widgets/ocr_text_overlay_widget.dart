import 'package:flutter/material.dart';
import 'package:edge_ai/models/ocr_text.dart';

class OcrTextOverlayWidget extends StatelessWidget {
  final List<OcrText> ocrTexts;

  const OcrTextOverlayWidget({super.key, required this.ocrTexts});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: ocrTexts.map((ocrText) {
        return Positioned(
          left: ocrText.rect.left,
          top: ocrText.rect.top,
          child: Container(
            padding: const EdgeInsets.all(2),
            color: Colors.red.withOpacity(0.5),
            child: Text(
              ocrText.text,
              style: const TextStyle(
                color: Colors.white,
                backgroundColor: Colors.red,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
