import '../../core/constants.dart';
import '../../domain/entities/user_sentence_task.dart';
import '../../domain/repositories/i_user_sentence_task_repository.dart';
import 'appwrite_service.dart';

class RemoteUserSentenceTaskRepository implements IUserSentenceTaskRepository {
  RemoteUserSentenceTaskRepository(this._service);

  final AppwriteService _service;

  @override
  Future<void> createOrUpdate(UserSentenceTask task) async {
    try {
      await _service.updateDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteUserSentenceTasks,
        documentId: task.id,
        data: task.toMap(),
      );
    } on Exception {
      await _service.createDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteUserSentenceTasks,
        data: task.toMap(),
      );
    }
  }
}
