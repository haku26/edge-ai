import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:edge_ai/models/ocr_text.dart';

final ocrTextProvider = StateProvider<List<OcrText>>((ref) => []);
