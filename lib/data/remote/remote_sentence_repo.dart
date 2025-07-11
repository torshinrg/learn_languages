import '../../core/constants.dart';
import '../../core/app_language.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/repositories/i_sentence_repository.dart';
import 'appwrite_service.dart';
import 'appwrite_utils.dart';

class RemoteSentenceRepository implements ISentenceRepository {
  RemoteSentenceRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Sentence>> fetchAll() async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSentences,
    );
    return docs.map((d) => Sentence.fromMap(d.data)).toList();
  }

  @override
  Future<List<Sentence>> fetchForWord(
    String wordText,
    String languageCode, {
    int? limit,
    bool onlyWithAudio = true,
    String? translationCode,
  }) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSentences,
    );
    var result = docs.map((d) => Sentence.fromMap(d.data)).where((s) {
      final text = s.text(languageCode).toLowerCase();
      return text.contains(wordText.toLowerCase());
    }).toList();
    if (translationCode != null) {
      result = result
          .where((s) => s.text(translationCode).isNotEmpty)
          .toList();
    }
    if (limit != null && result.length > limit) {
      result = result.sublist(0, limit);
    }
    return result;
  }
}
