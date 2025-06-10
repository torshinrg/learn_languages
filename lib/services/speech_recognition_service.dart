// lib/services/speech_recognition_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart'; // for rootBundle
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
    final assetName =
        (model == WhisperModel.tiny)
            ? 'assets/models/ggml-tiny-q8_0.bin'
            : 'assets/models/ggml-${model.modelName}.bin';

    try {
      final bytes = await rootBundle.load(assetName);
      final modelPath = await _controller.getPath(_model);
      await File(modelPath).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } catch (_) {
      await _controller.downloadModel(_model);
    }

    _initialized = true;
  }

  /// Transcribes a WAV file → plain text
  Future<String> transcribeFile({
    required String wavPath,
    required String lang, // e.g. 'es' for Spanish
  }) async {
    if (!_initialized) {
      throw StateError('SpeechRecognitionService.init() not called');
    }

    final file = File(wavPath);

    try {
      // Removed unsupported `threads` parameter
      final result = await _controller.transcribe(
        model: _model,
        audioPath: wavPath,
        lang: lang,
      );
      final text = result?.transcription.text.trim() ?? '';
      return text;
    } catch (e, st) {
      rethrow;
    }
  }
}
