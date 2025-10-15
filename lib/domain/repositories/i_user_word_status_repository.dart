import '../entities/user_word_status.dart';

abstract class IUserWordStatusRepository {
  Future<void> create(UserWordStatus status);
  Future<void> update(UserWordStatus status);
  Future<UserWordStatus> fetch(String userId, String wordId);
  Future<List<UserWordStatus>> fetchByStatus(String userId, WordStatus status);
  Future<int> count(String userId, WordStatus status);
}
