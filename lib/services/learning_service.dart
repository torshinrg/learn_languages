import '../domain/entities/sentence.dart';
import 'package:appwrite/appwrite.dart';
import '../domain/entities/user_word_status.dart';
import '../domain/entities/word.dart';
import '../domain/repositories/i_sentence_repository.dart';
import '../domain/repositories/i_user_word_status_repository.dart';
import '../domain/repositories/i_language_repository.dart';
import '../domain/entities/language.dart';
import '../domain/repositories/i_word_repository.dart';
import '../domain/repositories/i_word_sentence_link_repository.dart';

class LearningService {
  final IWordRepository _wordRepo;
  final ISentenceRepository _sentenceRepo;
  final IWordSentenceLinkRepository _wordSentenceLinkRepo;
  final IUserWordStatusRepository _userWordStatusRepo;
  final ILanguageRepository _languageRepo;
  Map<String, String>? _langIdByCodeCache;

  LearningService({
    required IWordRepository wordRepo,
    required ISentenceRepository sentenceRepo,
    required IWordSentenceLinkRepository wordSentenceLinkRepo,
    required IUserWordStatusRepository userWordStatusRepo,
    required ILanguageRepository languageRepo,
  }) : _wordRepo = wordRepo,
       _sentenceRepo = sentenceRepo,
       _wordSentenceLinkRepo = wordSentenceLinkRepo,
       _userWordStatusRepo = userWordStatusRepo,
       _languageRepo = languageRepo;

  Future<List<Word>> getTopWords(String languageId, int count) async {
    return _wordRepo.fetchTopN(languageId, count);
  }

  Future<List<Sentence>> getSentencesForWord(String wordId) async {
    return _sentenceRepo.fetchByWord(wordId);
  }

  Future<Sentence?> getTranslationForSentence({
    required Sentence sentence,
    required String nativeLanguageCode,
  }) async {
    final targetId = await _languageIdForCode(nativeLanguageCode);
    if (targetId == null) return null;
    if (sentence.groupId.isEmpty) return null;
    final matches = await _sentenceRepo.fetchByGroupAndLanguage(
      sentence.groupId,
      targetId,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  Future<void> updateWordStatus(
    String userId,
    String wordId,
    WordStatus status,
  ) async {
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
    final inProgress = await _userWordStatusRepo.count(
      userId,
      WordStatus.inProgress,
    );
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
    final statuses = await _userWordStatusRepo.fetchByStatus(
      userId,
      WordStatus.New,
    );
    final wordIds = statuses.map((s) => s.wordId).take(limit).toList();
    if (wordIds.isEmpty) return [];
    return _wordRepo.fetchByIds(wordIds);
  }

  Future<Map<String, Sentence>> getTranslationsForGroups({
    required Set<String> groupIds,
    required String nativeLanguageCode,
  }) async {
    final out = <String, Sentence>{};
    if (groupIds.isEmpty) return out;
    final targetId = await _languageIdForCode(nativeLanguageCode);
    if (targetId == null) return out;
    final list = await _sentenceRepo.fetchByGroupsAndLanguage(
      groupIds.toList(),
      targetId,
    );
    for (final s in list) {
      if (s.groupId.isNotEmpty && !out.containsKey(s.groupId)) {
        out[s.groupId] = s;
      }
    }
    return out;
  }

  Future<String?> resolveLanguageId(String code) {
    return _languageIdForCode(code);
  }

  Future<String?> _languageIdForCode(String code) async {
    if (_langIdByCodeCache == null) {
      final langs = await _languageRepo.fetchAll();
      _langIdByCodeCache = {for (final l in langs) l.code: l.id};
    }
    // return exact match or any available
    return _langIdByCodeCache![code] ??
        (_langIdByCodeCache!.isNotEmpty
            ? _langIdByCodeCache!.values.first
            : null);
  }

  /// Ensure there are initial New statuses for a given [languageCode].
  /// If the user has zero New statuses, seed using the top N words.
  Future<void> ensureSeedIfEmpty({
    required String userId,
    required String languageCode,
    int seedCount = 100,
  }) async {
    final current = await _userWordStatusRepo.count(userId, WordStatus.New);
    if (current > 0) return;

    // Resolve languageId by code from the public languages collection
    final languages = await _languageRepo.fetchAll();
    final Language lang = languages.firstWhere(
      (l) => l.code == languageCode,
      orElse:
          () =>
              languages.isNotEmpty
                  ? languages.first
                  : Language(id: 'en', code: 'en', name: 'English'),
    );

    print(
      '[Seed] Start ensureSeedIfEmpty: code=$languageCode -> langId=${lang.id}, target=$seedCount',
    );
    try {
      final topWords = await _wordRepo.fetchTopN(lang.id, seedCount);
      print('[Seed] Fetch with filter success, count=${topWords.length}');
      await _seedStatuses(userId, topWords);
    } on AppwriteException catch (e) {
      if (e.code == 400) {
        print('[Seed] 400 during filtered fetch. Retrying via repo fallback.');
        try {
          final topWords = await _wordRepo.fetchTopN(lang.id, seedCount);
          print('[Seed] Fallback repo returned count=${topWords.length}');
          await _seedStatuses(userId, topWords);
        } catch (e2) {
          print('[Seed] Final fallback aborted: $e2');
        }
      } else {
        rethrow;
      }
    }
    final after = await _userWordStatusRepo.count(userId, WordStatus.New);
    print('[Seed] Completed. New statuses now=$after');
  }

  Future<void> _seedStatuses(String userId, List<Word> words) async {
    int seeded = 0;
    for (final w in words) {
      await _userWordStatusRepo.create(
        UserWordStatus(
          id: '',
          userId: userId,
          wordId: w.id,
          status: WordStatus.New,
        ),
      );
      seeded++;
    }
    print('[Seed] Seeded $seeded statuses');
  }
}
