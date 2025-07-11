import '../../core/constants.dart';
import '../../domain/entities/custom_word.dart';
import '../../domain/repositories/i_custom_word_repository.dart';
import 'appwrite_service.dart';
import 'appwrite_utils.dart';

class RemoteCustomWordRepository implements ICustomWordRepository {
  RemoteCustomWordRepository(this._service);

  final AppwriteService _service;

  @override
  Future<void> add(CustomWord word) async {
    await _service.createDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteCustomWords,
      documentId: word.id,
      data: word.toMap(),
    );
  }

  @override
  Future<List<CustomWord>> fetchAll() async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteCustomWords,
    );
    return docs.map((d) => CustomWord.fromMap(d.data)).toList();
  }

  @override
  Future<List<CustomWord>> fetchByLanguage(String languageCode) async {
    final queries = AppwriteUtils.buildFilters({'language_code': languageCode});
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteCustomWords,
      queries: queries,
    );
    return docs.map((d) => CustomWord.fromMap(d.data)).toList();
  }

  @override
  Future<void> remove(String id) async {
    await _service.deleteDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteCustomWords,
      documentId: id,
    );
  }
}
