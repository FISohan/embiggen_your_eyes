import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  final ValueNotifier<bool> isSpeaking = ValueNotifier<bool>(false);

  TtsService() {
    _flutterTts.setCompletionHandler(() {
      isSpeaking.value = false;
    });
    _flutterTts.setLanguage("en-US");
    _flutterTts.setVoice({"name": "en-US-Standard-C", "locale": "en-US"});
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(1.0);
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      isSpeaking.value = true;
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    if (isSpeaking.value) {
      await _flutterTts.stop();
      isSpeaking.value = false;
    }
  }
}
