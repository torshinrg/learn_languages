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

  /// Original: mix of due + fresh
  Future<List<Word>> getDailyBatch(int count) async {
    final custom = await customRepo.fetchAll();
    final customWords = custom.map((cw) => Word(id: cw.id, text: cw.text)).toList();
    if (customWords.isNotEmpty) {
      // simply return them—never call scheduleNext here
      return customWords.take(count).toList();
    }
    
    final allSrs = await srsRepo.fetchAll();
    final scheduledIds = allSrs.map((e) => e.wordId).toSet();
    final due = await srsRepo.fetchDue();
    final dueWords = (await wordRepo.fetchAll())
        .where((w) => due.any((s) => s.wordId == w.id))
        .toList();
    if (dueWords.length >= count) return dueWords.take(count).toList();
    final needed = count - dueWords.length;
    final fresh = (await wordRepo.fetchAll())
        .where((w) => !scheduledIds.contains(w.id))
        .take(needed)
        .toList();
    return [...dueWords, ...fresh];
  }

  /// NEW: only words never scheduled in SRS
  Future<List<Word>> getFreshBatch(int count) async {
    final allSrs = await srsRepo.fetchAll();
    final scheduledIds = allSrs.map((e) => e.wordId).toSet();
    return (await wordRepo.fetchAll())
        .where((w) => !scheduledIds.contains(w.id))
        .take(count)
        .toList();
  }

  Future<List<Word>> getAllWords() => wordRepo.fetchAll();

  Future<void> markLearned(String wordId, bool success) {
    return srsRepo.scheduleNext(wordId, success);
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
