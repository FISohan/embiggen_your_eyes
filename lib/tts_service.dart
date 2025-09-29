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

  String _normalizeMarkdown(String markdownText) {
    // Remove headers
    String text = markdownText.replaceAll(
      RegExp(r'^#+\s+', multiLine: true),
      '',
    );

    // Corrected: Use replaceAllMapped to safely remove bold and italics
    // This uses a function to return the captured group ($1) safely.
    text = text.replaceAllMapped(
      RegExp(r'\*{1,2}(.*?)\*{1,2}'),
      (match) => match.group(1) ?? '', // Safely returns the captured text
    );

    // Remove list markers
    text = text.replaceAll(RegExp(r'^\s*[\*\-]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // Remove links, keeping the text
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1');

    // Remove blockquotes
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');

    // Remove horizontal rules
    text = text.replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '');

    // Remove empty lines
    text = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n');

    return text;
  }

  Future<void> speak(String text) async {
    final normalizedText = _normalizeMarkdown(text);
    if (normalizedText.isNotEmpty) {
      isSpeaking.value = true;
      await _flutterTts.speak(normalizedText);
    }
  }

  Future<void> stop() async {
    if (isSpeaking.value) {
      await _flutterTts.stop();
      isSpeaking.value = false;
    }
  }
}
