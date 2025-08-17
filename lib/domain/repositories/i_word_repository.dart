import '../entities/word.dart';

abstract class IWordRepository {
  Future<List<Word>> fetchTopN(String languageId, int n);
  Future<Word> fetchById(String wordId);
}