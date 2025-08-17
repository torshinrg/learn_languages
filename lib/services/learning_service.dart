import '../domain/entities/sentence.dart';
import '../domain/entities/user_word_status.dart';
import '../domain/entities/word.dart';
import '../domain/repositories/i_sentence_repository.dart';
import '../domain/repositories/i_user_word_status_repository.dart';
import '../domain/repositories/i_word_repository.dart';
import '../domain/repositories/i_word_sentence_link_repository.dart';

class LearningService {
  final IWordRepository _wordRepo;
  final ISentenceRepository _sentenceRepo;
  final IWordSentenceLinkRepository _wordSentenceLinkRepo;
  final IUserWordStatusRepository _userWordStatusRepo;

  LearningService({
    required IWordRepository wordRepo,
    required ISentenceRepository sentenceRepo,
    required IWordSentenceLinkRepository wordSentenceLinkRepo,
    required IUserWordStatusRepository userWordStatusRepo,
  })  : _wordRepo = wordRepo,
        _sentenceRepo = sentenceRepo,
        _wordSentenceLinkRepo = wordSentenceLinkRepo,
        _userWordStatusRepo = userWordStatusRepo;

  Future<List<Word>> getTopWords(String languageId, int count) async {
    return _wordRepo.fetchTopN(languageId, count);
  }

  Future<List<Sentence>> getSentencesForWord(String wordId) async {
    return _sentenceRepo.fetchByWord(wordId);
  }

  Future<void> updateWordStatus(String userId, String wordId, WordStatus status) async {
    final existing = await _userWordStatusRepo.fetch(userId, wordId);
    await _userWordStatusRepo.update(
      UserWordStatus(
        id: existing.id,
        userId: userId,
        wordId: wordId,
        status: status,
      ),
    );
  }

  Future<Map<WordStatus, int>> getProgressStats(String userId) async {
    final known = await _userWordStatusRepo.count(userId, WordStatus.known);
    final inProgress = await _userWordStatusRepo.count(userId, WordStatus.inProgress);
    final news = await _userWordStatusRepo.count(userId, WordStatus.New);
    return {
      WordStatus.known: known,
      WordStatus.inProgress: inProgress,
      WordStatus.New: news,
    };
  }

  Future<List<Word>> getWordsByStatus(String userId, WordStatus status) async {
    final statuses = await _userWordStatusRepo.fetchByStatus(userId, status);
    final wordIds = statuses.map((s) => s.wordId).toList();

    // This is inefficient. In a real app, you'd fetch these in a single query
    // or have the data denormalized.
    final List<Word> words = [];
    for (final wordId in wordIds) {
      words.add(await _wordRepo.fetchById(wordId));
    }
    return words;
  }

  Future<List<Word>> getDailyBatch(String userId, int limit) async {
    final statuses = await _userWordStatusRepo.fetchByStatus(userId, WordStatus.New);
    final wordIds = statuses.map((s) => s.wordId).take(limit).toList();

    final List<Word> words = [];
    for (final wordId in wordIds) {
      words.add(await _wordRepo.fetchById(wordId));
    }
    return words;
  }
}