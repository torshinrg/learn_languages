import 'package:flutter/foundation.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/presentation/providers/settings_provider.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/word.dart';
import '../../services/learning_service.dart';
import '../../data/remote/appwrite_service.dart';

class ReviewProvider extends ChangeNotifier {
  final LearningService _learning;
  final SettingsProvider _settings;
  final AppwriteService _appwriteService;

  List<Word> _dueWords = [];
  List<Sentence> _sentences = [];
  int _wordIndex = 0;
  int _sentenceIndex = 0;
  bool _initialLoaded = false;

  ReviewProvider(this._learning, this._settings, this._appwriteService) {
    loadDueWords();
  }

  List<Word> get dueWords => _dueWords;
  List<Sentence> get sentences => _sentences;
  int get wordIndex => _wordIndex;
  int get sentenceIndex => _sentenceIndex;
  bool get initialLoaded => _initialLoaded;

  Word? get currentWord => _dueWords.isNotEmpty ? _dueWords[_wordIndex] : null;

  Sentence? get currentSentence =>
      _sentences.isNotEmpty ? _sentences[_sentenceIndex] : null;

  Future<void> loadDueWords() async {
    try {
      final user = await _appwriteService.account.get();
      final due = await _learning.getWordsByStatus(user.$id, WordStatus.inProgress);
      _dueWords = due;
      _wordIndex = 0;
      if (_dueWords.isNotEmpty) {
        await _loadSentencesForCurrent();
      }
    } catch (e) {
      _dueWords = [];
    }
    notifyListeners();
  }

  Future<void> _loadSentencesForCurrent() async {
    _initialLoaded = false;
    try {
      _sentences = await _learning.getSentencesForWord(currentWord!.id);
    } catch (e) {
      _sentences = [];
    }
    _sentenceIndex = 0;
    _initialLoaded = true;
    notifyListeners();
  }

  void nextSentence() {
    if (_sentences.isEmpty) return;
    _sentenceIndex = (_sentenceIndex + 1) % _sentences.length;
    notifyListeners();
  }

  void prevSentence() {
    if (_sentences.isEmpty) return;
    _sentenceIndex =
        (_sentenceIndex - 1 + _sentences.length) % _sentences.length;
    notifyListeners();
  }

  Future<void> markWord(WordStatus status) async {
    try {
      final user = await _appwriteService.account.get();
      await _learning.updateWordStatus(user.$id, currentWord!.id, status);

      if (_wordIndex >= _dueWords.length - 1) {
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
    } catch (e) {
      // handle error
    }

    notifyListeners();
  }
}
