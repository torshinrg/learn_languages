import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/i_word_repository.dart';
import 'appwrite_service.dart';

class RemoteWordRepository implements IWordRepository {
  RemoteWordRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Word>> fetchTopN(String languageId, int n) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteWords,
      queries: [
        Query.equal('languageId', [languageId]),
        Query.orderAsc('frequencyRank'),
        Query.limit(n),
      ],
    );
    return docs.map((d) => Word.fromMap(d.data)).toList();
  }

  @override
  Future<Word> fetchById(String wordId) async {
    final doc = await _service.getDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteWords,
      documentId: wordId,
    );
    return Word.fromMap(doc.data);
  }
}