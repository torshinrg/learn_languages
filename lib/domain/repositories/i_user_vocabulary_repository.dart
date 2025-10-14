import '../entities/user_vocabulary.dart';

abstract class IUserVocabularyRepository {
  Future<void> create(UserVocabulary vocabulary);
  Future<List<UserVocabulary>> fetch(String userId);
}
