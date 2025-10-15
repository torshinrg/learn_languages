import '../entities/sentence.dart';

abstract class ISentenceRepository {
  Future<List<Sentence>> fetchByWord(String wordId);
  Future<List<Sentence>> fetchByGroupAndLanguage(String groupId, String languageId);
  Future<List<Sentence>> fetchByGroupsAndLanguage(List<String> groupIds, String languageId);
}
