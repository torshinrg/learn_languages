// lib/services/audio_check_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:whisper_ggml/whisper_ggml.dart';
import 'speech_recognition_service.dart';
import 'pronunciation_scoring_service.dart';

/// Holds both the pronunciation score (0.0–1.0) and the raw
/// transcription of the user’s audio.
class PronunciationResult {
  final double score;
  final String userText;
  PronunciationResult(this.score, this.userText);
}

class AudioCheckService {
  final _speech = SpeechRecognitionService();
  final _scorer = PronunciationScoringService();
  bool _ready = false;
  final _refTextCache = <String, String>{};

  /// Call this from your dialog’s `initState()` (or as soon as you know
  /// refUrl+sentenceId) to download & transcribe the reference ahead of time.
  Future<void> preloadReference({
    required String refUrl,
    required String sentenceId,
    String lang = 'es',
  }) async {
    // 1) download
    final file = await downloadRef(refUrl, sentenceId);
    // 2) transcribe
    final text = await _speech.transcribeFile(wavPath: file.path, lang: lang);
    _refTextCache[sentenceId] = text;
    print('📝 [AudioCheckService] cached refText="$text"');
  }

  /// Must be called once before any compare()/transcribeUser() calls.
  Future<void> init({WhisperModel model = WhisperModel.tiny}) async {
    if (_ready) {
      print('✅ [AudioCheckService] init() skipped, already ready');
      return;
    }
    print('🔄 [AudioCheckService] init(model=${model.modelName})');
    await _speech.init(model: model);
    _ready = true;
    print('✅ [AudioCheckService] init complete');
  }

  /// Straight transcript of a user WAV, no scoring.
  Future<String> transcribeUser(String userAudioPath, String lang) {
    return _speech.transcribeFile(wavPath: userAudioPath, lang: lang);
  }

  /// Download a reference WAV from [url] into the cache dir as `ref_<id>.wav`.
  Future<File> downloadRef(String url, String id) async {
    print('🔄 [AudioCheckService] downloadRef(url=$url, id=$id)');
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/ref_$id.wav';
    final file = File(path);

    if (await file.exists()) {
      print('📁 [AudioCheckService] Using cached ref at $path');
    } else {
      print('📥 [AudioCheckService] Downloading ref from $url');
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        print('❌ [AudioCheckService] download failed (${resp.statusCode})');
        throw HttpException(
          'Failed to download reference',
          uri: Uri.parse(url),
        );
      }
      await file.writeAsBytes(resp.bodyBytes);
      print('📁 [AudioCheckService] Saved ref to $path');
    }
    return file;
  }

  /// Compare the user’s recorded WAV against the given [expectedText].
  Future<PronunciationResult> compare({
    required String userAudioPath,
    required String expectedText,
    String lang = 'es',
  }) async {
    await init();

    // 1) Transcribe only the user recording
    final userText = await _speech.transcribeFile(
      wavPath: userAudioPath,
      lang: lang,
    );

    // 2) Score against the provided expectedText
    final score = _scorer.score(expectedText.trim(), userText);

    return PronunciationResult(score, userText);
  }
}
