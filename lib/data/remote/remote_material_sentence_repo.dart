import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

import '../../core/constants.dart';
import '../../domain/entities/material_sentence.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/repositories/i_material_sentence_repository.dart';
import 'appwrite_service.dart';

class RemoteMaterialSentenceRepository implements IMaterialSentenceRepository {
  RemoteMaterialSentenceRepository(this._service);

  final AppwriteService _service;

  static const _materialField = 'readingMaterials';
  static const _orderField = 'order';

  @override
  Future<MaterialSentencePage> fetchByMaterial(
    String materialId, {
    int? limit,
    int? startAfterOrder,
  }) async {
    final baseQueries = <String>[
      Query.equal(_materialField, [materialId]),
    ];

    if (startAfterOrder != null) {
      baseQueries.add(Query.greaterThan(_orderField, startAfterOrder));
    }

    DocumentList response;
    try {
      final orderedQueries = [
        ...baseQueries,
        if (limit != null && limit > 0) Query.limit(limit),
        Query.orderAsc(_orderField),
      ];
      print('[MaterialSentenceRepo] primary queries: $orderedQueries');
      response = await _service.listDocumentsRaw(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteMaterialSentences,
        queries: orderedQueries,
      );
    } on AppwriteException catch (e) {
      print(
        '[MaterialSentenceRepo] primary query failed: code=${e.code} message=${e.message}',
      );
      if (e.code == 400) {
        print('[MaterialSentenceRepo] retrying without order');
        response = await _service.listDocumentsRaw(
          databaseId: kAppwriteDatabaseId,
          collectionId: kAppwriteMaterialSentences,
          queries: [
            ...baseQueries,
            if (limit != null && limit > 0) Query.limit(limit),
          ],
        );
        response = DocumentList(
          total: response.total,
          documents: List<Document>.from(response.documents)..sort(
            (a, b) => _parseOrder(
              a.data[_orderField],
            ).compareTo(_parseOrder(b.data[_orderField])),
          ),
        );
      } else {
        rethrow;
      }
    }

    final docs = response.documents;
    if (docs.isEmpty) {
      print(
        '[MaterialSentenceRepo] query returned 0 documents for materialId=$materialId',
      );
    }

    final List<MaterialSentence> results = [];
    for (final doc in docs) {
      final data = doc.data;
      // Ensure sentence relation is present; if not, skip gracefully.
      final rawSentence = data['sentences'];
      if (rawSentence == null) {
        continue;
      }

      Sentence? sentence;
      if (rawSentence is Map<String, dynamic>) {
        sentence = Sentence.fromMap(rawSentence);
      } else if (rawSentence is Document) {
        sentence = Sentence.fromMap(rawSentence.data);
      } else if (rawSentence is List && rawSentence.isNotEmpty) {
        final first = rawSentence.first;
        if (first is Map<String, dynamic>) {
          sentence = Sentence.fromMap(first);
        } else if (first is Document) {
          sentence = Sentence.fromMap(first.data);
        } else if (first is String) {
          // minimal fallback: fetch the sentence by id directly
          sentence = await _fetchSentenceById(first);
        }
      } else if (rawSentence is String) {
        sentence = await _fetchSentenceById(rawSentence);
      }

      // Skip if we still cannot resolve sentence content.
      if (sentence == null) {
        continue;
      }

      results.add(
        MaterialSentence(
          id: data['\$id'] as String,
          materialId: materialId,
          sentenceId: sentence.id,
          order: _parseOrder(data[_orderField]),
          sentence: sentence,
        ),
      );
    }

    return MaterialSentencePage(items: results, total: response.total);
  }

  Future<Sentence?> _fetchSentenceById(String sentenceId) async {
    if (sentenceId.isEmpty) return null;
    try {
      final doc = await _service.getDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteSentences,
        documentId: sentenceId,
      );
      return Sentence.fromMap(doc.data);
    } on AppwriteException {
      return null;
    }
  }

  int _parseOrder(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
