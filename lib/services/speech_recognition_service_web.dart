// lib/services/speech_recognition_service_web.dart

/// A minimal stub used on the web where whisper_ggml is unavailable.
class SpeechRecognitionService {
  Future<void> init({dynamic model}) async {
    // No-op on web. Whisper models are not supported.
  }

  Future<String> transcribeFile({
    required String wavPath,
    required String lang,
  }) async {
    throw UnsupportedError('Whisper speech recognition not supported on web');
  }
}
