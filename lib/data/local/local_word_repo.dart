// lib/data/local/local_word_repo.dart

import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/i_word_repository.dart';

/// A repository that reads “words” from a language-specific table,
/// e.g. `en_words`, `es_words`, `ru_words`, `de_words`, etc.
/// Each of those tables only has one column: `text`.
/// We look up the first element of SharedPreferences['learningLanguages'] to decide.
/// This version logs what it’s doing for debugging.
class LocalWordRepository implements IWordRepository {
  final Database db;
  LocalWordRepository(this.db);

  /// Reads SharedPreferences["learningLanguages"] (e.g. ['es','de',...])
  /// and returns "<firstCode>_words". Defaults to 'es_words' if none set.
  Future<String> _getTable() async {
    final prefs = await SharedPreferences.getInstance();
    final codes = prefs.getStringList('learningLanguages') ?? ['es'];
    if (codes.isEmpty) {
      print(
        '🔍 [LocalWordRepo] No learningLanguages found, defaulting to "es_words"',
      );
      return 'es_words';
    }
    final code = codes.first;
    final tableName = '${code}_words';
    print(
      '🔍 [LocalWordRepo] learningLanguages=$codes, using table="$tableName"',
    );
    return tableName;
  }

  @override
  Future<List<Word>> fetchAll() async {
    final table = await _getTable();
    // Log the raw query attempt
    print('🔍 [LocalWordRepo] Running query on table="$table"');
    List<Map<String, Object?>> rows;
    try {
      rows = await db.query(table);
    } catch (e) {
      print('❌ [LocalWordRepo] ERROR querying table "$table": $e');
      return <Word>[];
    }

    print('🔍 [LocalWordRepo] Retrieved ${rows.length} rows from "$table"');
    final words = <Word>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final value = r['word'];
      if (value is String) {
        words.add(
          Word(
            id: value,
            text: value,
            translation: null,
            sentence: null,
            type: WordType.normal,
          ),
        );
      } else {
        print(
          '⚠️ [LocalWordRepo] Skipping row $i in table="$table" because '
          'r["text"]=${value.runtimeType} (${value?.toString() ?? "null"})',
        );
      }
    }
    print(
      '🔍 [LocalWordRepo] Mapped ${words.length} valid Word(s) from "$table"',
    );
    return words;
  }

  @override
  Future<void> addOrUpdate(Word word) async {
    // We do not support inserts/updates on these static language tables.
    print(
      '❌ [LocalWordRepo] addOrUpdate() called unexpectedly for "${word.text}"',
    );
    throw UnimplementedError(
      'addOrUpdate() is not supported for language-specific tables.',
    );
  }

  @override
  Future<void> remove(String id) async {
    // We do not support deletions on these static language tables.
    print('❌ [LocalWordRepo] remove() called unexpectedly for id="$id"');
    throw UnimplementedError(
      'remove() is not supported for language-specific tables.',
    );
  }
}
