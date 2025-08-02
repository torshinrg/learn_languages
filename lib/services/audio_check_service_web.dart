// lib/services/audio_check_service_web.dart

import 'pronunciation_scoring_service.dart';

class PronunciationResult {
  final double score;
  final String userText;
  PronunciationResult(this.score, this.userText);
}

/// Minimal stub for the web. Actual Whisper-based audio comparison is not
/// supported so methods either no-op or throw if misused.
class AudioCheckService {
  final _scorer = PronunciationScoringService();

  Future<void> init({dynamic model}) async {
    // No initialization needed on web.
  }

  Future<void> preloadReference({
    required String refUrl,
    required String sentenceId,
    String lang = 'es',
  }) async {
    // No-op; references are not used on web.
  }

  Future<String> transcribeUser(String userAudioPath, String lang) async {
    throw UnsupportedError('transcribeUser is not available on web');
  }

  Future<PronunciationResult> compare({
    required String userAudioPath,
    required String expectedText,
    String lang = 'es',
  }) async {
    throw UnsupportedError('compare() is not available on web');
  }

  Future<dynamic> downloadRef(String url, String id) async {
    throw UnsupportedError('downloadRef() is not available on web');
  }
}
