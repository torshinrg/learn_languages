/// lib/services/learning_service.dart
library;

import 'package:learn_languages/domain/repositories/i_custom_word_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/audio_link.dart';
import '../domain/entities/word.dart';
import '../domain/entities/sentence.dart';
import '../domain/repositories/i_word_repository.dart';
import '../domain/repositories/i_sentence_repository.dart';
import '../domain/repositories/i_audio_repository.dart';
import '../domain/repositories/i_srs_repository.dart';

class LearningService {
  final IWordRepository wordRepo;
  final ISentenceRepository sentenceRepo;
  final IAudioRepository audioRepo;
  final ISRSRepository srsRepo;
  final ICustomWordRepository customRepo;

  LearningService({
    required this.wordRepo,
    required this.sentenceRepo,
    required this.audioRepo,
    required this.srsRepo,
    required this.customRepo,
  });

  Future<String> _activeLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final codes = prefs.getStringList('learningLanguages') ?? ['es'];
    if (codes.isEmpty) return 'es';
    return codes.first;
  }

  Future<List<Word>> _allWords() async {
    final base = await wordRepo.fetchAll();
    final lang = await _activeLanguageCode();
    final custom = await customRepo.fetchByLanguage(lang);
    final customWords = custom
        .map(
          (c) => Word(
            id: c.id,
            text: c.text,
            translation: null,
            sentence: null,
            type: WordType.custom,
          ),
        )
        .toList();
    return [...base, ...customWords];
  }

  Future<List<Word>> getDailyBatch(int count) async {
    final allWords = await _allWords();
    final custom = allWords.where((w) => w.type == WordType.custom).toList();
    if (custom.isNotEmpty) return custom.take(count).toList();

    final dueData = await srsRepo.fetchDue();
    final due =
        allWords.where((w) => dueData.any((s) => s.wordId == w.id)).toList();
    if (due.length >= count) return due.take(count).toList();

    final scheduledIds =
        (await srsRepo.fetchAll()).map((e) => e.wordId).toSet();
    final needed = count - due.length;
    final fresh =
        allWords
            .where((w) => !scheduledIds.contains(w.id))
            .take(needed)
            .toList();
    return [...due, ...fresh];
  }

  Future<List<Word>> getFreshBatch(int count) async {
    final allWords = await _allWords();
    final allSrs = await srsRepo.fetchAll();
    final scheduledIds = allSrs.map((e) => e.wordId).toSet();

    final unscheduled =
        allWords.where((w) => !scheduledIds.contains(w.id)).toList();
    final custom = unscheduled.where((w) => w.type == WordType.custom).toList();
    if (custom.length >= count) return custom.take(count).toList();

    final remaining = count - custom.length;
    final normal =
        unscheduled
            .where((w) => w.type != WordType.custom)
            .take(remaining)
            .toList();
    return [...custom, ...normal];
  }

  Future<List<Word>> getAllWords() => _allWords();

  Future<void> markLearned(String wordId, bool success) {
    return srsRepo.scheduleNext(wordId, success);
  }

  /// NEW: Mark a word as completely known/mastered so it never appears again.
  Future<void> markAsKnown(String wordId) async {
    // Repetition threshold = 3.
    await srsRepo.scheduleNextWithQuality(wordId, 5);
    await srsRepo.scheduleNextWithQuality(wordId, 5);
    await srsRepo.scheduleNextWithQuality(wordId, 5);
  }

  Future<List<Sentence>> getInitialSentencesForWord(
    String wordText,
    String languageCode, {
    int limit = 3,
    bool requireAudio = true,
  }) {
    return sentenceRepo.fetchForWord(
      wordText,
      languageCode,
      limit: limit,
      onlyWithAudio: requireAudio,
    );
  }

  Future<List<Sentence>> getRemainingSentencesForWord(
    String wordText,
    List<String> excludeIds,
    String languageCode,
    {bool requireAudio = true}
  ) async {
    final all = await sentenceRepo.fetchForWord(
      wordText,
      languageCode,
      onlyWithAudio: requireAudio,
    );
    return all
        .where((s) => !excludeIds.contains(s.id(languageCode)))
        .toList();
  }

  Future<List<AudioLink>> getAudioForSentence(
    String sentenceId,
    String languageCode,
  ) {
    return audioRepo.fetchForSentence(sentenceId, languageCode);
  }

  Future<List<Word>> getDueWords() async {
    final srsList = await srsRepo.fetchDue();
    final allWords = await _allWords();
    return allWords.where((w) => srsList.any((s) => s.wordId == w.id)).toList();
  }

  Future<void> markWithQuality(String wordId, int quality) {
    return srsRepo.scheduleNextWithQuality(wordId, quality);
  }
}
