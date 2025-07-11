import 'package:appwrite/models.dart';

import '../../core/constants.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/i_word_repository.dart';
import 'appwrite_service.dart';
import 'appwrite_utils.dart';

class RemoteWordRepository implements IWordRepository {
  RemoteWordRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Word>> fetchAll() async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteWords,
    );
    return docs.map((d) => Word.fromMap(d.data)).toList();
  }

  @override
  Future<void> addOrUpdate(Word word) async {
    await _service.createDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteWords,
      documentId: word.id,
      data: word.toMap(),
    );
  }

  @override
  Future<void> remove(String id) async {
    await _service.deleteDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteWords,
      documentId: id,
    );
  }
}
