import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../core/schema_fields.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/word_sentence_link.dart';
import '../../domain/repositories/i_sentence_repository.dart';
import 'appwrite_service.dart';

class RemoteSentenceRepository implements ISentenceRepository {
  RemoteSentenceRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Sentence>> fetchByWord(String wordId) async {
    // Preferred path: fetch the word document and read its relation field to sentences
    try {
      final wordDoc = await _service.getDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteWords,
        documentId: wordId,
      );

      final data = wordDoc.data;
      final relKey = SchemaFields.wordExamplesRef; // typically 'example'
      final rel = data[relKey];

      // Extract sentence IDs from relation field which may be:
      // - List<String>
      // - List<Map> with {'\$id': '...'}
      // - Single String (edge)
      final List<String> sentenceIds = [];
      if (rel is List) {
        for (final item in rel) {
          if (item is String) {
            sentenceIds.add(item);
          } else if (item is Map && item['\$id'] is String) {
            sentenceIds.add(item['\$id'] as String);
          }
        }
      } else if (rel is String) {
        sentenceIds.add(rel);
      }

      if (sentenceIds.isNotEmpty) {
        try {
          final sentenceDocs = await _service.getDocuments(
            databaseId: kAppwriteDatabaseId,
            collectionId: kAppwriteSentences,
            queries: [
              Query.equal(r'$id', sentenceIds),
              Query.limit(sentenceIds.length),
            ],
          );
          return sentenceDocs.map((d) => Sentence.fromMap(d.data)).toList();
        } on AppwriteException catch (e) {
          if (e.code != 400) rethrow;
          // Fallback to per-id fetch
          print('[SentenceRepo] 400 on batch fetch (relation); falling back to per-id');
          final List<Sentence> out = [];
          for (final id in sentenceIds) {
            try {
              final doc = await _service.getDocument(
                databaseId: kAppwriteDatabaseId,
                collectionId: kAppwriteSentences,
                documentId: id,
              );
              out.add(Sentence.fromMap(doc.data));
            } catch (_) {
              // ignore individual failures
            }
          }
          return out;
        }
      }
    } catch (e) {
      // If the relation-based path fails or word not found, return empty.
      print('[SentenceRepo] Relation path failed for word=$wordId: $e');
    }

    // No sentences resolved
    return [];
  }

  @override
  Future<List<Sentence>> fetchByGroupAndLanguage(String groupId, String languageId) async {
    try {
      final groupField = SchemaFields.sentenceGroupId;
      final langField = SchemaFields.sentenceLanguageRef;
      final sentenceDocs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteSentences,
        queries: [
          Query.equal(groupField, [groupId]),
          Query.equal(langField, [languageId]),
          Query.limit(10),
        ],
      );
      return sentenceDocs.map((d) => Sentence.fromMap(d.data)).toList();
    } on AppwriteException catch (e) {
      if (e.code == 400) {
        // Fallback: fetch by group only, then filter client-side by languageId
        print('[SentenceRepo] 400 on group+lang; fallback group-only');
        final sentenceDocs = await _service.getDocuments(
          databaseId: kAppwriteDatabaseId,
          collectionId: kAppwriteSentences,
          queries: [Query.equal(SchemaFields.sentenceGroupId, [groupId]), Query.limit(50)],
        );
        final items = sentenceDocs.map((d) => Sentence.fromMap(d.data)).toList();
        return items.where((s) => s.languageId == languageId).toList();
      }
      rethrow;
    }
  }

  @override
  Future<List<Sentence>> fetchByGroupsAndLanguage(List<String> groupIds, String languageId) async {
    if (groupIds.isEmpty) return [];
    try {
      final groupField = SchemaFields.sentenceGroupId;
      final langField = SchemaFields.sentenceLanguageRef;
      final sentenceDocs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteSentences,
        queries: [
          Query.equal(groupField, groupIds),
          Query.equal(langField, [languageId]),
          Query.limit(groupIds.length * 2),
        ],
      );
      return sentenceDocs.map((d) => Sentence.fromMap(d.data)).toList();
    } on AppwriteException catch (e) {
      if (e.code == 400) {
        // Fallback: fetch by groups only, then filter client-side by languageId
        print('[SentenceRepo] 400 on groups+lang; fallback groups-only');
        final sentenceDocs = await _service.getDocuments(
          databaseId: kAppwriteDatabaseId,
          collectionId: kAppwriteSentences,
          queries: [Query.equal(SchemaFields.sentenceGroupId, groupIds), Query.limit(groupIds.length * 5)],
        );
        final items = sentenceDocs.map((d) => Sentence.fromMap(d.data)).toList();
        return items.where((s) => s.languageId == languageId).toList();
      }
      rethrow;
    }
  }
}
