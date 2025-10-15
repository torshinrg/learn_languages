import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/word.dart';
import '../../core/schema_fields.dart';
import '../../domain/repositories/i_word_repository.dart';
import 'appwrite_service.dart';

class RemoteWordRepository implements IWordRepository {
  RemoteWordRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Word>> fetchTopN(String languageId, int n) async {
    try {
      final List<String> queries = [];

      // Apply language filter only if we detected a field name
      final langField = SchemaFields.wordLanguageRef;
      if (langField.isNotEmpty) {
        queries.add(Query.equal(langField, [languageId]));
      }

      // Apply ordering only if a valid rank field exists
      final rankField = SchemaFields.wordRank;
      if (rankField.isNotEmpty) {
        queries.add(Query.orderAsc(rankField));
      }
      // Only include words that have example relation present
      final examplesField = SchemaFields.wordExamplesRef;
      if (examplesField.isNotEmpty) {
        queries.add(Query.isNotNull(examplesField));
      }
      queries.add(Query.limit(n));

      final docs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteWords,
        queries: queries,
      );
      return docs.map((d) => Word.fromMap(d.data)).toList();
    } on AppwriteException catch (e) {
      if (e.code == 400) {
        // Fallback: no filters, no order — then client-filter by language and examples if possible
        print('[WordsRepo] 400; retry unfiltered (n=$n)');
        final docs = await _service.getDocuments(
          databaseId: kAppwriteDatabaseId,
          collectionId: kAppwriteWords,
          queries: [
            Query.limit(n * 5),
          ], // overfetch to allow client-side filtering
        );

        final examplesField = SchemaFields.wordExamplesRef;
        final langField = SchemaFields.wordLanguageRef;

        final List<Word> out = [];
        for (final d in docs) {
          final data = d.data;
          // Language filter if detectable
          if (langField.isNotEmpty && data.containsKey(langField)) {
            if (data[langField] != languageId) continue;
          }
          // Example relation must exist and be non-null; if it's a list, non-empty
          if (examplesField.isNotEmpty && data.containsKey(examplesField)) {
            final rel = data[examplesField];
            if (rel == null) continue;
            if (rel is List && rel.isEmpty) continue;
          } else if (examplesField.isNotEmpty) {
            // if we expect the field but it's missing, skip
            continue;
          }
          out.add(Word.fromMap(data));
          if (out.length >= n) break;
        }
        return out;
      }
      rethrow;
    }
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

  @override
  Future<List<Word>> fetchByIds(List<String> wordIds) async {
    if (wordIds.isEmpty) return [];
    try {
      final docs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteWords,
        queries: [Query.equal(r'$id', wordIds), Query.limit(wordIds.length)],
      );
      return docs.map((d) => Word.fromMap(d.data)).toList();
    } on AppwriteException catch (e) {
      if (e.code != 400) rethrow;
      // Fallback: fetch per-id
      final List<Word> out = [];
      for (final id in wordIds) {
        try {
          final doc = await _service.getDocument(
            databaseId: kAppwriteDatabaseId,
            collectionId: kAppwriteWords,
            documentId: id,
          );
          out.add(Word.fromMap(doc.data));
        } catch (_) {
          // ignore
        }
      }
      return out;
    }
  }

  @override
  Future<Word?> findByLemma(String lemma, String languageId) async {
    final normalized = lemma.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final primary = await _findSingleByField(
      'normilized_words',
      normalized,
      languageId,
    );
    if (primary != null) {
      return primary;
    }
    return _findSingleByField('word', normalized, languageId);
  }

  @override
  Future<Word?> findBySurface(String surface, String languageId) async {
    final normalized = surface.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    final wordFieldResult = await _findSingleByField(
      'word',
      normalized,
      languageId,
    );
    if (wordFieldResult != null) return wordFieldResult;
    return _findSingleByField('normilized_words', normalized, languageId);
  }

  Future<Word?> _findSingleByField(
    String field,
    String value,
    String languageId,
  ) async {
    final queries = <String>[
      Query.equal('languages', [languageId]),
      Query.equal(field, [value]),
      Query.limit(1),
    ];

    try {
      final docs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteWords,
        queries: queries,
      );
      if (docs.isEmpty) return null;
      return Word.fromMap(docs.first.data);
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        return null;
      }
      rethrow;
    }
  }
}
