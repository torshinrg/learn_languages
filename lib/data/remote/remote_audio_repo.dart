import '../../core/constants.dart';
import '../../domain/entities/audio_link.dart';
import '../../domain/repositories/i_audio_repository.dart';
import 'appwrite_service.dart';
import 'appwrite_utils.dart';

class RemoteAudioRepository implements IAudioRepository {
  RemoteAudioRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<AudioLink>> fetchForSentence(
    String sentenceId,
    String languageCode,
  ) async {
    final queries = AppwriteUtils.buildFilters({
      'sentence_id': sentenceId,
      'language_code': languageCode,
    });
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteAudioLinks,
      queries: queries,
    );
    return docs.map((d) => AudioLink.fromMap(d.data)).toList();
  }
}
