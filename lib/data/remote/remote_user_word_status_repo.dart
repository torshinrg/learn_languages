import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/user_word_status.dart';
import '../../domain/repositories/i_user_word_status_repository.dart';
import 'appwrite_service.dart';

class RemoteUserWordStatusRepository implements IUserWordStatusRepository {
  RemoteUserWordStatusRepository(this._service);

  final AppwriteService _service;

  @override
  Future<void> create(UserWordStatus status) async {
    await _service.createDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserWordStatus,
      data: status.toMap(),
    );
  }

  @override
  Future<void> update(UserWordStatus status) async {
    await _service.updateDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserWordStatus,
      documentId: status.id,
      data: status.toMap(),
    );
  }

  @override
  Future<UserWordStatus> fetch(String userId, String wordId) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserWordStatus,
      queries: [
        Query.equal('userId', [userId]),
        Query.equal('wordId', [wordId]),
      ],
    );
    return UserWordStatus.fromMap(docs.first.data);
  }

  @override
  Future<List<UserWordStatus>> fetchByStatus(
      String userId, WordStatus status) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserWordStatus,
      queries: [
        Query.equal('userId', [userId]),
        Query.equal('status', [status.name]),
      ],
    );
    return docs.map((d) => UserWordStatus.fromMap(d.data)).toList();
  }

  @override
  Future<int> count(String userId, WordStatus status) async {
    final result = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserWordStatus,
      queries: [
        Query.equal('userId', [userId]),
        Query.equal('status', [status.name]),
      ],
    );
    return result.length;
  }
}
