// lib/presentation/providers/review_provider.dart

import 'package:flutter/foundation.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/word.dart';
import '../../services/learning_service.dart';
import '../../services/srs_service.dart';

class ReviewProvider extends ChangeNotifier {
  final LearningService _learning;
  final SRSService _srs;

  List<Word> _dueWords = [];
  List<Sentence> _sentences = [];
  int _wordIndex = 0;
  int _sentenceIndex = 0;
  bool _initialLoaded = false;

  ReviewProvider(this._learning, this._srs) {
    loadDueWords();
  }

  // PUBLIC GETTERS
  List<Word> get dueWords => _dueWords;
  List<Sentence> get sentences => _sentences;
  int get wordIndex => _wordIndex;
  int get sentenceIndex => _sentenceIndex;
  bool get initialLoaded => _initialLoaded;

  Word? get currentWord =>
      _dueWords.isNotEmpty ? _dueWords[_wordIndex] : null;

  Sentence? get currentSentence => _sentences.isNotEmpty
      ? _sentences[_sentenceIndex]
      : null;

  /// Load all due words, then fetch sentences for the first word.
  Future<void> loadDueWords() async {
    _dueWords = await _learning.getDueWords();
    _wordIndex = 0;
    if (_dueWords.isNotEmpty) {
      await _loadSentencesForCurrent();
    }
    notifyListeners();
  }

  /// Fetch initial and then remaining examples.
  Future<void> _loadSentencesForCurrent() async {
    _initialLoaded = false;
    _sentences = await _learning.getInitialSentencesForWord(
      currentWord!.text,
      limit: 3,
    );
    _sentenceIndex = 0;
    _initialLoaded = true;
    notifyListeners();

    // Fetch the rest in background
    final rest = await _learning.getRemainingSentencesForWord(
      currentWord!.text,
      _sentences.map((s) => s.id).toList(),
    );
    _sentences.addAll(rest);
    notifyListeners();
  }

  /// Navigate sentences
  void nextSentence() {
    if (_sentences.isEmpty) return;
    _sentenceIndex =
        (_sentenceIndex + 1) % _sentences.length;
    notifyListeners();
  }

  void prevSentence() {
    if (_sentences.isEmpty) return;
    _sentenceIndex =
        (_sentenceIndex - 1 + _sentences.length) % _sentences.length;
    notifyListeners();
  }

  /// Mark current word with a quality score 0–5,
  /// then advance to the next word (or clear list).
  Future<void> markWord(int quality) async {
    final wordId = currentWord!.id;
    await _learning.markWithQuality(wordId, quality);

    if (_wordIndex >= _dueWords.length - 1) {
      // last word done
      _dueWords = [];
    } else {
      _dueWords.removeAt(_wordIndex);
      if (_wordIndex >= _dueWords.length) {
        _wordIndex = _dueWords.length - 1;
      }
    }

    if (_dueWords.isNotEmpty) {
      await _loadSentencesForCurrent();
    }

    notifyListeners();
  }
}
