import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/user_vocabulary.dart';
import '../../domain/repositories/i_user_vocabulary_repository.dart';
import 'appwrite_service.dart';

class RemoteUserVocabularyRepository implements IUserVocabularyRepository {
  RemoteUserVocabularyRepository(this._service);

  final AppwriteService _service;

  @override
  Future<void> create(UserVocabulary vocabulary) async {
    await _service.createDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserVocabulary,
      data: vocabulary.toMap(),
    );
  }

  @override
  Future<List<UserVocabulary>> fetch(String userId) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteUserVocabulary,
      queries: [
        Query.equal('userId', [userId]),
      ],
    );
    return docs.map((d) => UserVocabulary.fromMap(d.data)).toList();
  }
}
