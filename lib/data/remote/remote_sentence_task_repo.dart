import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/sentence_task.dart';
import '../../domain/repositories/i_sentence_task_repository.dart';
import 'appwrite_service.dart';

class RemoteSentenceTaskRepository implements ISentenceTaskRepository {
  RemoteSentenceTaskRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<SentenceTask>> fetchBySentence(String sentenceId) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSentenceTasks,
      queries: [
        Query.equal('sentenceId', [sentenceId]),
      ],
    );
    return docs.map((d) => SentenceTask.fromMap(d.data)).toList();
  }
}
