import 'dart:convert';

import 'package:appwrite/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:learn_languages/core/constants.dart';
import 'package:learn_languages/data/local/reading_progress_store.dart';
import 'package:learn_languages/data/remote/appwrite_service.dart';
import 'package:learn_languages/data/remote/remote_material_sentence_repo.dart';
import 'package:learn_languages/data/remote/remote_reading_material_repo.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAppwriteService extends AppwriteService {
  _FakeAppwriteService(this._documentsByCollection)
    : super(endpoint: 'https://example.com/v1', projectId: 'demo');

  final Map<String, List<Document>> _documentsByCollection;

  @override
  Future<DocumentList> listDocumentsRaw({
    required String databaseId,
    required String collectionId,
    List<String>? queries,
    bool retried = false,
  }) async {
    final docs = List<Document>.from(
      _documentsByCollection[collectionId] ?? [],
    );

    if (collectionId == kAppwriteReadingMaterials) {
      var filtered = docs;
      final languageFilter = _extractEqualValue(queries, 'languages');
      if (languageFilter != null) {
        filtered =
            filtered
                .where((doc) => doc.data['languages'] == languageFilter)
                .toList();
      }
      final total = filtered.length;
      filtered.sort(
        (a, b) => (a.data['title'] ?? '').toString().compareTo(
          (b.data['title'] ?? '').toString(),
        ),
      );
      final limit = _extractLimit(queries);
      if (limit != null && filtered.length > limit) {
        filtered = filtered.sublist(0, limit);
      }
      return DocumentList(total: total, documents: filtered);
    }

    if (collectionId == kAppwriteMaterialSentences) {
      var filtered = docs;
      final materialFilter = _extractEqualValue(queries, 'readingMaterials');
      final greaterThan = _extractGreaterThan(queries, 'order');
      if (materialFilter != null) {
        filtered =
            filtered
                .where((doc) => doc.data['readingMaterials'] == materialFilter)
                .toList();
      }
      if (greaterThan != null) {
        filtered =
            filtered
                .where((doc) => (doc.data['order'] as int) > greaterThan)
                .toList();
      }
      filtered.sort(
        (a, b) => (a.data['order'] as int).compareTo(b.data['order'] as int),
      );
      final total = filtered.length;
      final limit = _extractLimit(queries);
      if (limit != null && filtered.length > limit) {
        filtered = filtered.sublist(0, limit);
      }
      return DocumentList(total: total, documents: filtered);
    }

    return DocumentList(total: docs.length, documents: docs);
  }

  @override
  Future<List<Document>> getDocuments({
    required String databaseId,
    required String collectionId,
    List<String>? queries,
  }) async {
    final result = await listDocumentsRaw(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: queries,
    );
    return result.documents;
  }

  @override
  Future<Document> getDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    bool retried = false,
  }) async {
    final docs = _documentsByCollection[collectionId] ?? [];
    return docs.firstWhere((doc) => doc.$id == documentId);
  }

  String? _extractEqualValue(List<String>? queries, String field) {
    if (queries == null) return null;
    for (final q in queries) {
      if (q.startsWith('{')) {
        final map = jsonDecode(q) as Map<String, dynamic>;
        if (map['method'] == 'equal' && map['attribute'] == field) {
          final values = map['values'];
          if (values is List && values.isNotEmpty) {
            return values.first.toString();
          }
        }
        continue;
      }
      if (q.startsWith('equal("$field"')) {
        final start = q.indexOf('[');
        final end = q.indexOf(']');
        if (start == -1 || end == -1 || end <= start) continue;
        final value = q.substring(start + 1, end).replaceAll('"', '');
        return value;
      }
    }
    return null;
  }

  int? _extractGreaterThan(List<String>? queries, String field) {
    if (queries == null) return null;
    for (final q in queries) {
      if (q.startsWith('{')) {
        final map = jsonDecode(q) as Map<String, dynamic>;
        if (map['attribute'] == field &&
            (map['method'] == 'greaterThan' ||
                map['method'] == 'greaterThanEqual')) {
          final values = map['values'];
          if (values is List && values.isNotEmpty) {
            final value = values.first;
            if (value is num) return value.toInt();
            return int.tryParse(value.toString());
          }
        }
        continue;
      }
      if (q.startsWith('greaterThan("$field"') ||
          q.startsWith('greaterThanEqual("$field"')) {
        return int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }
    return null;
  }

  int? _extractLimit(List<String>? queries) {
    if (queries == null) return null;
    for (final q in queries) {
      if (q.startsWith('{')) {
        final map = jsonDecode(q) as Map<String, dynamic>;
        if (map['method'] == 'limit') {
          final values = map['values'];
          if (values is List && values.isNotEmpty) {
            final value = values.first;
            if (value is num) return value.toInt();
            return int.tryParse(value.toString());
          }
        }
        continue;
      }
      if (q.startsWith('limit(')) {
        final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
        return int.tryParse(digits);
      }
    }
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteReadingMaterialRepository', () {
    test('filters materials by language and search', () async {
      final docs = [
        _buildMaterialDocument(
          id: 'mat1',
          languageId: 'langA',
          title: 'Libro Uno',
        ),
        _buildMaterialDocument(
          id: 'mat2',
          languageId: 'langB',
          title: 'Poema Dos',
        ),
        _buildMaterialDocument(
          id: 'mat3',
          languageId: 'langA',
          title: 'Poema Tres',
          typeName: 'book',
        ),
      ];
      final service = _FakeAppwriteService({kAppwriteReadingMaterials: docs});
      final repo = RemoteReadingMaterialRepository(service);

      final langAResults = await repo.listByLanguage('langA');
      expect(langAResults.map((e) => e.id), ['mat1', 'mat3']);

      final searchResults = await repo.listByLanguage('langA', search: 'Poema');
      expect(searchResults.map((e) => e.id), ['mat3']);

      final typeResults = await repo.listByLanguage('langA', typeName: 'book');
      expect(typeResults.map((e) => e.id), ['mat3']);
    });
  });

  group('RemoteMaterialSentenceRepository', () {
    test('returns ordered sentences with embedded data', () async {
      final docs = [
        _buildMaterialSentenceDocument(
          id: 'ms1',
          materialId: 'mat1',
          order: 2,
          sentenceId: 'sent2',
          text: 'Segunda frase',
        ),
        _buildMaterialSentenceDocument(
          id: 'ms2',
          materialId: 'mat1',
          order: 1,
          sentenceId: 'sent1',
          text: 'Primera frase',
        ),
      ];
      final service = _FakeAppwriteService({kAppwriteMaterialSentences: docs});
      final repo = RemoteMaterialSentenceRepository(service);

      final page = await repo.fetchByMaterial('mat1', limit: 10);
      expect(page.total, 2);
      expect(page.items.length, 2);
      expect(page.items.first.order, 1);
      expect(page.items.first.sentence?.content, 'Primera frase');
      expect(page.items.last.order, 2);
    });
  });

  group('ReadingProgressStore', () {
    test('persists and restores progress records', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ReadingProgressStore();

      await store.saveProgress('mat1', 7);
      final record = await store.loadProgress('mat1');
      expect(record, isNotNull);
      expect(record!.lastOrder, 7);

      final all = await store.allProgress();
      expect(all['mat1']?.lastOrder, 7);

      await store.saveProgress('mat1', 9);
      final updated = await store.loadProgress('mat1');
      expect(updated!.lastOrder, 9);
    });
  });
}

Document _buildMaterialDocument({
  required String id,
  required String languageId,
  required String title,
  String typeName = 'article',
}) {
  final data = <String, dynamic>{
    '\$id': id,
    '\$collectionId': kAppwriteReadingMaterials,
    '\$databaseId': kAppwriteDatabaseId,
    '\$createdAt': '',
    '\$updatedAt': '',
    '\$permissions': const <String>[],
    'title': title,
    'languages': languageId,
    'materialsTypes': {'type_name': typeName},
  };
  return Document(
    $id: id,
    $collectionId: kAppwriteReadingMaterials,
    $databaseId: kAppwriteDatabaseId,
    $createdAt: '',
    $updatedAt: '',
    $permissions: const [],
    data: data,
  );
}

Document _buildMaterialSentenceDocument({
  required String id,
  required String materialId,
  required int order,
  required String sentenceId,
  required String text,
}) {
  final sentence = {
    '\$id': sentenceId,
    'languageId': 'langA',
    'text': text,
    'content': text,
    'group_id': 'grp1',
    'audio_id': 'audio_$sentenceId',
    'tokenLemma': [text.toLowerCase()],
    'tokenSurfaces': [text],
  };

  final data = <String, dynamic>{
    '\$id': id,
    '\$collectionId': kAppwriteMaterialSentences,
    '\$databaseId': kAppwriteDatabaseId,
    '\$createdAt': '',
    '\$updatedAt': '',
    '\$permissions': const <String>[],
    'readingMaterials': materialId,
    'order': order,
    'sentences': sentence,
  };

  return Document(
    $id: id,
    $collectionId: kAppwriteMaterialSentences,
    $databaseId: kAppwriteDatabaseId,
    $createdAt: '',
    $updatedAt: '',
    $permissions: const [],
    data: data,
  );
}
