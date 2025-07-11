import '../../core/constants.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/i_task_repository.dart';
import 'appwrite_service.dart';
import 'appwrite_utils.dart';

class RemoteTaskRepository implements ITaskRepository {
  RemoteTaskRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Task>> fetchTasksByType(String taskType, String locale) async {
    final queries = AppwriteUtils.buildFilters({
      'task_type': taskType,
      'locale': locale,
    });
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteTasks,
      queries: queries,
    );
    return docs.map((d) => Task.fromMap(d.data)).toList();
  }

  @override
  Future<void> saveTaskHistory({
    required String taskId,
    String? sentenceId,
    String? result,
  }) async {
    await _service.createDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteTaskHistory,
      data: {
        'task_id': taskId,
        'sentence_id': sentenceId,
        'result': result,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }
}
