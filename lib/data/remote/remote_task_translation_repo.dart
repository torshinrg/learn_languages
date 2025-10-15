import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/task_translation.dart';
import '../../domain/repositories/i_task_translation_repository.dart';
import 'appwrite_service.dart';

class RemoteTaskTranslationRepository implements ITaskTranslationRepository {
  RemoteTaskTranslationRepository(this._service);

  final AppwriteService _service;

  @override
  Future<TaskTranslation?> fetch(String taskId, String languageCode) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteTaskTranslations,
      queries: [
        Query.equal('taskId', [taskId]),
        Query.equal('languageCode', [languageCode]),
      ],
    );
    if (docs.isEmpty) {
      return null;
    }
    return TaskTranslation.fromMap(docs.first.data);
  }
}
