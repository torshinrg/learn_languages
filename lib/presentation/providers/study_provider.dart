import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
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
  Sentence? _translation;
  Map<String, Sentence> _translations = {};
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
  Sentence? get translation => _translation;
  Map<String, Sentence> get translationsMap => Map.unmodifiable(_translations);

  Word? get currentWord => _words.isNotEmpty ? _words[_wordIndex] : null;

  Sentence? get currentSentence =>
      _sentences.isNotEmpty ? _sentences[_sentenceIndex] : null;

  Future<void> loadWords() async {
    try {
      final user = await _appwriteService.account.get();
      // Ensure there is something to study for anonymous users
      final codes = _settings.learningLanguageCodes;
      final langCode = codes.isNotEmpty ? codes.first : 'en';
      try {
        await _learning.ensureSeedIfEmpty(
          userId: user.$id,
          languageCode: langCode,
          seedCount: 100,
        );
      } on AppwriteException catch (e) {
        if (e.code == 400) {
          print('[StudyProvider] 400 during seeding, retrying via fallback');
          await _learning.ensureSeedIfEmpty(
            userId: user.$id,
            languageCode: langCode,
            seedCount: 100,
          );
        } else {
          rethrow;
        }
      }

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
    try {
      _sentences = await _learning.getSentencesForWord(currentWord!.id);
    } catch (e) {
      // If sentences backend path isn't ready, keep going with empty sentences
      _sentences = [];
      print('[StudyProvider] Failed to load sentences for word ${currentWord!.id}: $e');
    }
    _sentenceIndex = 0;
    await _prefetchTranslations();
    _translation = currentSentence != null
        ? _translations[currentSentence!.groupId]
        : null;
    _initialLoaded = true;
    notifyListeners();
  }

  Future<void> _prefetchTranslations() async {
    _translations = {};
    _translation = null;
    if (_sentences.isEmpty) return;
    final nativeCode = _settings.nativeLanguageCode ?? 'en';
    final groups = _sentences.map((s) => s.groupId).where((g) => g.isNotEmpty).toSet();
    if (groups.isEmpty) return;
    try {
      _translations = await _learning.getTranslationsForGroups(
        groupIds: groups,
        nativeLanguageCode: nativeCode,
      );
    } catch (_) {
      _translations = {};
    }
  }

  void nextSentence() {
    if (_sentences.isEmpty) return;
    _sentenceIndex = (_sentenceIndex + 1) % _sentences.length;
    final current = currentSentence;
    _translation = current != null ? _translations[current.groupId] : null;
    notifyListeners();
  }

  void prevSentence() {
    if (_sentences.isEmpty) return;
    _sentenceIndex =
        (_sentenceIndex - 1 + _sentences.length) % _sentences.length;
    final current = currentSentence;
    _translation = current != null ? _translations[current.groupId] : null;
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
