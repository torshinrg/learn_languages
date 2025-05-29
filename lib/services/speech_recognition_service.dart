// lib/services/speech_recognition_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';          // for rootBundle
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart'; // WhisperController, WhisperModel
import 'package:http/http.dart' as http;
import 'pronunciation_scoring_service.dart';

class SpeechRecognitionService {
  final WhisperController _controller = WhisperController();
  WhisperModel _model = WhisperModel.tiny;
  bool _initialized = false;

  /// Call once at app startup (before transcribing).
  Future<void> init({WhisperModel model = WhisperModel.tiny}) async {
    if (_initialized) return;
    _model = model;

    // pick the right asset for tiny vs. others
    final assetName = (model == WhisperModel.tiny)
        ? 'assets/models/ggml-tiny-q8_0.bin'
        : 'assets/models/ggml-${model.modelName}.bin';

    try {
      print('🔄 [SpeechRecognition] loading model from $assetName');
      final bytes     = await rootBundle.load(assetName);
      final modelPath = await _controller.getPath(_model);
      await File(modelPath).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } catch (_) {
      print('🔄 [SpeechRecognition] asset load failed, downloading model ${model.modelName}');
      await _controller.downloadModel(_model);
    }

    _initialized = true;
    print('✅ [SpeechRecognition] initialized model=${model.modelName}');
  }



  /// Transcribes a WAV file → plain text
  Future<String> transcribeFile({
    required String wavPath,
    required String lang, // e.g. 'es' for Spanish
  }) async {
    if (!_initialized) {
      throw StateError('SpeechRecognitionService.init() not called');
    }
    print('⚙️ [SpeechRecognitionService] Preparing to transcribe: $wavPath');

    final file = File(wavPath);
    print('⚙️ [SpeechRecognitionService] exists=${file.existsSync()}, '
        'size=${file.existsSync() ? file.lengthSync() : -1}');
    print('⚙️ [SpeechRecognitionService] Calling whisper transcribe...');

    try {
      // Removed unsupported `threads` parameter
      final result = await _controller.transcribe(
        model: _model,
        audioPath: wavPath,
        lang: lang,
      );
      final text = result?.transcription.text.trim() ?? '';
      print('✅ [SpeechRecognitionService] Transcription success: "$text"');
      return text;
    } catch (e, st) {
      print('❌ [SpeechRecognitionService] Transcription failed: $e\n$st');
      rethrow;
    }
  }
}
