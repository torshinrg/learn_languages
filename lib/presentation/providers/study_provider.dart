// lib/presentation/providers/study_provider.dart

import 'package:flutter/foundation.dart';
import '../../services/srs_service.dart';
import '../../services/learning_service.dart';
import '../../domain/entities/word.dart';

/// Provides today's study batch to the UI.
class StudyProvider extends ChangeNotifier {
  final LearningService _learning;
  final SRSService _srs;
  List<Word> _batch = [];
  List<Word> _lastBatch = [];

  StudyProvider(this._learning, this._srs);

  List<Word> get batch => _batch;
  List<Word> get lastBatch => _lastBatch;

  /// Load [count] words into the batch.
  Future<void> loadBatch(int count) async {
    _batch = await _learning.getDailyBatch(count);
    _lastBatch = List.from(_batch);
    notifyListeners();
  }

  /// Mark the first word in the batch.
  Future<void> markWord(bool success) async {
    if (_batch.isEmpty) return;
    final word = _batch.removeAt(0);
    await _learning.markLearned(word.id, success);
    notifyListeners();
  }

  void resetToLastBatch() {
    _batch = List.from(_lastBatch);
    notifyListeners();
  }

  Future<void> skipWord() async {
    if (_batch.isEmpty) return;
    _batch.removeAt(0);
    notifyListeners();
  }
}
