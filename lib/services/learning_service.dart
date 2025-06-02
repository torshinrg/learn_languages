// File: lib/services/learning_service.dart

import 'package:learn_languages/domain/repositories/i_custom_word_repository.dart';

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

  Future<List<Word>> getDailyBatch(int count) async {
    final allWords = await wordRepo.fetchAll();

    // 1) custom words first
    final custom = allWords.where((w) => w.type == WordType.custom).toList();
    if (custom.isNotEmpty) {
      return custom.take(count).toList();
    }

    // 2) then due by SRS
    final dueData = await srsRepo.fetchDue();
    final due = allWords
        .where((w) => dueData.any((s) => s.wordId == w.id))
        .toList();
    if (due.length >= count) return due.take(count).toList();

    // 3) fill with fresh
    final scheduledIds =
    (await srsRepo.fetchAll()).map((e) => e.wordId).toSet();
    final needed = count - due.length;
    final fresh = allWords
        .where((w) => !scheduledIds.contains(w.id))
        .take(needed)
        .toList();

    return [...due, ...fresh];
  }

  Future<List<Word>> getFreshBatch(int count) async {
    // 1) Load all words and SRS entries
    final allWords = await wordRepo.fetchAll();
    final allSrs = await srsRepo.fetchAll();
    final scheduledIds = allSrs.map((e) => e.wordId).toSet();

    // 2) Identify unscheduled words (never reviewed)
    final unscheduled =
    allWords.where((w) => !scheduledIds.contains(w.id)).toList();

    // 3) Prioritize custom words
    final custom = unscheduled.where((w) => w.type == WordType.custom).toList();
    if (custom.length >= count) {
      return custom.take(count).toList();
    }

    // 4) Fill the remainder with normal unscheduled words
    final remaining = count - custom.length;
    final normal = unscheduled
        .where((w) => w.type != WordType.custom)
        .take(remaining)
        .toList();

    // 5) Return combined list: customs first, then normals
    return [...custom, ...normal];
  }

  Future<List<Word>> getAllWords() => wordRepo.fetchAll();

  Future<void> markLearned(String wordId, bool success) {
    return srsRepo.scheduleNext(wordId, success);
  }

  /// NEW: Mark a word as completely known/mastered so it never appears again.
  Future<void> markAsKnown(String wordId) async {
    // Repetition threshold for “mastered” is 3.
    // Each scheduleNextWithQuality(wordId, 5) will bump repetition by 1 (since 5 >= 3).
    // First call creates entry with repetition=1; second → 2; third → 3.
    await srsRepo.scheduleNextWithQuality(wordId, 5);
    await srsRepo.scheduleNextWithQuality(wordId, 5);
    await srsRepo.scheduleNextWithQuality(wordId, 5);
  }

  Future<List<Sentence>> getInitialSentencesForWord(
      String wordText, {
        int limit = 3,
      }) {
    return sentenceRepo.fetchForWord(wordText, limit: limit);
  }

  Future<List<Sentence>> getRemainingSentencesForWord(
      String wordText,
      List<String> excludeIds,
      ) async {
    final all = await sentenceRepo.fetchForWord(wordText);
    return all.where((s) => !excludeIds.contains(s.id)).toList();
  }

  Future<List<AudioLink>> getAudioForSentence(String sentenceId) {
    return audioRepo.fetchForSentence(sentenceId);
  }

  Future<List<Word>> getDueWords() async {
    final srsList = await srsRepo.fetchDue();
    final allWords = await wordRepo.fetchAll();
    return allWords.where((w) => srsList.any((s) => s.wordId == w.id)).toList();
  }

  Future<void> markWithQuality(String wordId, int quality) {
    return srsRepo.scheduleNextWithQuality(wordId, quality);
  }
}
