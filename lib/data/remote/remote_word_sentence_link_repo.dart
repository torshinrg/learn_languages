import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/word_sentence_link.dart';
import '../../core/schema_fields.dart';
import '../../domain/repositories/i_word_sentence_link_repository.dart';
import 'appwrite_service.dart';

class RemoteWordSentenceLinkRepository implements IWordSentenceLinkRepository {
  RemoteWordSentenceLinkRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<WordSentenceLink>> fetchByWord(String wordId) async {
    final field = SchemaFields.linkWordRef;
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteWordSentenceLinks,
      queries: [Query.equal(field, [wordId])],
    );
    return docs.map((d) => WordSentenceLink.fromMap(d.data)).toList();
  }
}
