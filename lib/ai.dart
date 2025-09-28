import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';

Stream<GenerateContentResponse> askAI(String prompt, Uint8List img) {
  final model = FirebaseAI.googleAI().generativeModel(
    model: 'gemini-2.5-flash',
  );
  final textPart = TextPart(prompt);
  final imgPart = InlineDataPart("image/png", img);

  return model.generateContentStream([
    Content.multi([textPart, imgPart]),
  ]);
}
