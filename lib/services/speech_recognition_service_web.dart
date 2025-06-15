import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechRecognitionService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  Future<void> init({dynamic model}) async {
    if (_initialized) return;
    _initialized = await _speech.initialize();
  }

  Future<String> transcribeFile({
    required String wavPath,
    required String lang,
  }) async {
    if (!_initialized) {
      throw StateError('SpeechRecognitionService.init() not called');
    }

    if (!_speech.isAvailable) {
      return '';
    }

    final completer = Completer<String>();
    _speech.listen(
      localeId: lang,
      listenFor: const Duration(seconds: 10),
      onResult: (result) {
        if (result.finalResult) {
          completer.complete(result.recognizedWords.trim());
        }
      },
    );
    final text = await completer.future;
    await _speech.stop();
    return text;
  }
}
