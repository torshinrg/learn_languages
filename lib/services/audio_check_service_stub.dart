class PronunciationResult {
  final double score;
  final String userText;
  PronunciationResult(this.score, this.userText);
}

class AudioCheckService {
  Future<void> preloadReference({
    required String refUrl,
    required String sentenceId,
    String lang = 'es',
  }) async {}

  Future<void> init({dynamic model}) async {}

  Future<String> transcribeUser(String userAudioPath, String lang) async => '';

  Future<PronunciationResult> compare({
    required String userAudioPath,
    required String expectedText,
    String lang = 'es',
  }) async {
    return PronunciationResult(0.0, '');
  }
}
