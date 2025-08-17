import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/material_sentence.dart';
import '../../domain/repositories/i_material_sentence_repository.dart';
import 'appwrite_service.dart';

class RemoteMaterialSentenceRepository implements IMaterialSentenceRepository {
  RemoteMaterialSentenceRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<MaterialSentence>> fetchByMaterial(String materialId) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteMaterialSentences,
      queries: [
        Query.equal('materialId', [materialId]),
      ],
    );
    return docs.map((d) => MaterialSentence.fromMap(d.data)).toList();
  }
}
