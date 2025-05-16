// lib/presentation/providers/vocabulary_provider.dart

import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../domain/entities/word.dart';
import '../../domain/entities/srs_data.dart';
import '../../services/learning_service.dart';
import '../../services/srs_service.dart';

class VocabularyProvider extends ChangeNotifier {
  final LearningService _learning;
  final SRSService _srs;

  List<Word> _learningNow = [];
  List<Word> _pending     = [];
  List<Word> _learned     = [];

  List<Word> get learningNow => _learningNow;
  List<Word> get pending     => _pending;
  List<Word> get learned     => _learned;

  VocabularyProvider(this._learning, this._srs) {
    _loadAll();
  }

  Future<void> _loadAll() async {
    final allWords = await _learning.getAllWords();
    final allSrs   = await _srs.fetchAllData();
    final nowMs    = DateTime.now().millisecondsSinceEpoch;

    // Map wordId → SRSData
    final srsMap = { for (var s in allSrs) s.wordId : s };

    _learningNow = [];
    _learned     = [];
    _pending     = [];

    for (final w in allWords) {
      final s = srsMap[w.id];
      if (s == null) {
        // never scheduled ⇒ pending
        _pending.add(w);
      } else if (s.repetition >= kMasterRepetitionThreshold) {
        // mastered
        _learned.add(w);
      } else if (s.nextReview.millisecondsSinceEpoch <= nowMs) {
        // due right now ⇒ learning now
        _learningNow.add(w);
      } else {
        // scheduled but not due ⇒ pending
        _pending.add(w);
      }
    }

    // sort alphabetically
    _learningNow.sort((a, b) => a.text.compareTo(b.text));
    _pending    .sort((a, b) => a.text.compareTo(b.text));
    _learned    .sort((a, b) => a.text.compareTo(b.text));

    notifyListeners();
  }

  /// Call to refresh lists (e.g. after a review)
  Future<void> refresh() => _loadAll();
}
