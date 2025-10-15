import 'package:appwrite/appwrite.dart';

import '../core/constants.dart';
import '../core/schema_fields.dart';
import '../data/remote/appwrite_service.dart';

/// Probes public collections to detect the correct field names at runtime.
class AppwriteSchemaProbe {
  final AppwriteService _service;
  AppwriteSchemaProbe(this._service);

  Future<void> run() async {
    await _probeLanguages();
    await _probeWords();
  }

  Future<void> _probeLanguages() async {
    try {
      final docs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteLanguages,
        queries: [Query.limit(1)],
      );
      if (docs.isNotEmpty) {
        final data = docs.first.data;
        final detected = SchemaFields.detectKey(
          data,
          ['code', 'language_code', 'langCode', 'lang', 'locale'],
          fallback: 'code',
        );
        SchemaFields.languageCode = detected;
        print('[SchemaProbe] Languages: code field="$detected" (sample=${data.keys})');
      }
    } catch (e) {
      print('[SchemaProbe] Languages probe failed: $e');
    }
  }

  Future<void> _probeWords() async {
    try {
      final docs = await _service.getDocuments(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteWords,
        queries: [Query.limit(1)],
      );
      if (docs.isNotEmpty) {
        final data = docs.first.data;
        // Language ref (may not exist in this collection)
        final langKey = SchemaFields.detectKey(
          data,
          ['languageId', 'language', 'langId', 'language_code', 'lang'],
          fallback: '',
        );
        SchemaFields.wordLanguageRef = langKey;

        // Text/content key
        final textKey = SchemaFields.detectKey(
          data,
          ['text', 'word', 'value', 'term'],
          fallback: 'text',
        );
        SchemaFields.wordText = textKey;

        // Optional rank key
        final rankKey = SchemaFields.detectKey(
          data,
          ['frequencyRank', 'rank', 'freq', 'score'],
          fallback: '',
        );
        // Only keep if it actually exists
        SchemaFields.wordRank = rankKey.isNotEmpty && data.containsKey(rankKey)
            ? rankKey
            : '';

        print('[SchemaProbe] Words: langRef="${SchemaFields.wordLanguageRef}" text="${SchemaFields.wordText}" rank="${SchemaFields.wordRank}" (sample=${data.keys})');
      } else {
        print('[SchemaProbe] Words probe: no documents');
      }
    } catch (e) {
      print('[SchemaProbe] Words probe failed: $e');
    }
  }
}
