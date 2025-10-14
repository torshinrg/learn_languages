import '../entities/word.dart';

abstract class IWordRepository {
  Future<List<Word>> fetchTopN(String languageId, int n);
  Future<Word> fetchById(String wordId);
  Future<List<Word>> fetchByIds(List<String> wordIds);
  Future<Word?> findByLemma(String lemma, String languageId);
  Future<Word?> findBySurface(String surface, String languageId);
}
