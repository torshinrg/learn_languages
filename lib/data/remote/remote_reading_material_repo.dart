import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/reading_material.dart';
import '../../domain/repositories/i_reading_material_repository.dart';
import 'appwrite_service.dart';

class RemoteReadingMaterialRepository implements IReadingMaterialRepository {
  RemoteReadingMaterialRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<ReadingMaterial>> fetchByLanguage(String languageId) async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteReadingMaterials,
      queries: [
        Query.equal('languageId', [languageId]),
      ],
    );
    return docs.map((d) => ReadingMaterial.fromMap(d.data)).toList();
  }
}
