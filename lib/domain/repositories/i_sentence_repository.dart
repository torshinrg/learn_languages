import '../entities/sentence.dart';

abstract class ISentenceRepository {
  Future<List<Sentence>> fetchByWord(String wordId);
}