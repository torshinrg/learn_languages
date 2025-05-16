// lib/services/learning_service.dart

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

  LearningService({
    required this.wordRepo,
    required this.sentenceRepo,
    required this.audioRepo,
    required this.srsRepo,
  });

  Future<List<Word>> getDailyBatch(int count) async {
    // 1) all scheduled entries
    final allSrs = await srsRepo.fetchAll();
    final scheduledIds = allSrs.map((e) => e.wordId).toSet();

    // 2) only those due now
    final due = await srsRepo.fetchDue();
    final dueWords = (await wordRepo.fetchAll())
        .where((w) => due.any((s) => s.wordId == w.id))
        .toList();

    if (dueWords.length >= count) {
      return dueWords.take(count).toList();
    }

    // 3) fill with truly fresh words (never scheduled)
    final needed = count - dueWords.length;
    final fresh = (await wordRepo.fetchAll())
        .where((w) => !scheduledIds.contains(w.id))
        .take(needed)
        .toList();

    return [...dueWords, ...fresh];
  }

  Future<List<Word>> getAllWords() => wordRepo.fetchAll();

  Future<void> markLearned(String wordId, bool success) {
    return srsRepo.scheduleNext(wordId, success);
  }

  /// Phase 1: fetch up to [limit] random examples quickly.
  Future<List<Sentence>> getInitialSentencesForWord(String wordText, {int limit = 3}) {
    return sentenceRepo.fetchForWord(wordText, limit: limit);
  }

  /// Phase 2: fetch *all* remaining examples (excluding [excludeIds]).
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
