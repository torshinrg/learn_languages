import '../entities/user_sentence_task.dart';

abstract class IUserSentenceTaskRepository {
  Future<void> createOrUpdate(UserSentenceTask task);
}
