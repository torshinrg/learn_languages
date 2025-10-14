import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

import '../../core/constants.dart';
import '../../domain/entities/reading_material.dart';
import '../../domain/repositories/i_reading_material_repository.dart';
import 'appwrite_service.dart';

class RemoteReadingMaterialRepository implements IReadingMaterialRepository {
  RemoteReadingMaterialRepository(this._service);

  final AppwriteService _service;

  static const _languageField = 'languages';

  @override
  Future<List<ReadingMaterial>> listByLanguage(
    String languageId, {
    String? typeName,
    String? search,
  }) async {
    final baseQueries = <String>[
      Query.equal(_languageField, [languageId]),
    ];
    List<Document> docs;
    try {
      print(
        '[ReadingMaterialRepo] primary queries: ${[...baseQueries, Query.limit(200), Query.orderAsc('title')]}',
      );
      docs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteReadingMaterials,
        queries: [...baseQueries, Query.limit(200), Query.orderAsc('title')],
      );
    } on AppwriteException catch (e) {
      print(
        '[ReadingMaterialRepo] primary query failed: code=${e.code} message=${e.message}',
      );
      if (e.code == 400) {
        print('[ReadingMaterialRepo] retrying without order');
        docs = await _service.getDocuments(
          databaseId: kAppwriteDatabaseId,
          collectionId: kAppwriteReadingMaterials,
          queries: baseQueries,
        );
        docs.sort((a, b) {
          final aTitle = (a.data['title'] ?? '').toString();
          final bTitle = (b.data['title'] ?? '').toString();
          return aTitle.compareTo(bTitle);
        });
      } else {
        rethrow;
      }
    }

    if (docs.isEmpty) {
      print(
        '[ReadingMaterialRepo] query returned 0 documents for languageId=$languageId',
      );
    }

    Iterable<ReadingMaterial> materials = docs.map(
      (doc) => ReadingMaterial.fromMap(doc.data),
    );

    if (typeName != null && typeName.isNotEmpty) {
      final typeLower = typeName.toLowerCase();
      materials = materials.where((m) => m.typeName.toLowerCase() == typeLower);
    }

    if (search != null && search.trim().isNotEmpty) {
      final term = search.trim().toLowerCase();
      materials = materials.where((m) => m.title.toLowerCase().contains(term));
    }

    return materials.toList(growable: false);
  }

  @override
  Future<ReadingMaterial?> getById(String id) async {
    try {
      final doc = await _service.getDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteReadingMaterials,
        documentId: id,
      );
      return ReadingMaterial.fromMap(doc.data);
    } on AppwriteException {
      return null;
    }
  }

  @override
  Future<List<ReadingMaterial>> fetchByLanguage(String languageId) {
    return listByLanguage(languageId);
  }
}
