import 'package:flutter/foundation.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/presentation/providers/settings_provider.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/word.dart';
import '../../services/learning_service.dart';
import '../../data/remote/appwrite_service.dart';

class StudyProvider extends ChangeNotifier {
  final LearningService _learning;
  final SettingsProvider _settings;
  final AppwriteService _appwriteService;

  List<Word> _words = [];
  List<Sentence> _sentences = [];
  int _wordIndex = 0;
  int _sentenceIndex = 0;
  bool _initialLoaded = false;

  StudyProvider(this._learning, this._settings, this._appwriteService) {
    loadWords();
  }

  List<Word> get words => _words;
  List<Sentence> get sentences => _sentences;
  int get wordIndex => _wordIndex;
  int get sentenceIndex => _sentenceIndex;
  bool get initialLoaded => _initialLoaded;

  Word? get currentWord => _words.isNotEmpty ? _words[_wordIndex] : null;

  Sentence? get currentSentence =>
      _sentences.isNotEmpty ? _sentences[_sentenceIndex] : null;

  Future<void> loadWords() async {
    try {
      final user = await _appwriteService.account.get();
      final dailyBatch = await _learning.getDailyBatch(user.$id, _settings.dailyCount);
      _words = dailyBatch;
      _wordIndex = 0;
      if (_words.isNotEmpty) {
        await _loadSentencesForCurrent();
      }
    } catch (e) {
      _words = [];
    }
    notifyListeners();
  }

  Future<void> _loadSentencesForCurrent() async {
    _initialLoaded = false;
    _sentences = await _learning.getSentencesForWord(currentWord!.id);
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

      if (_wordIndex >= _words.length - 1) {
        _words = [];
      } else {
        _words.removeAt(_wordIndex);
        if (_wordIndex >= _words.length) {
          _wordIndex = _words.length - 1;
        }
      }

      if (_words.isNotEmpty) {
        await _loadSentencesForCurrent();
      }
    } catch (e) {
      // handle error
    }

    notifyListeners();
  }
}