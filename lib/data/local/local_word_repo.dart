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
      return 'es_words';
    }
    final code = codes.first;
    final tableName = '${code}_words';

    return tableName;
  }

  @override
  Future<List<Word>> fetchAll() async {
    final table = await _getTable();

    List<Map<String, Object?>> rows;
    try {
      rows = await db.query(table);
    } catch (e) {
      return <Word>[];
    }

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
      } else {}
    }
    return words;
  }

  @override
  Future<void> addOrUpdate(Word word) async {
    // We do not support inserts/updates on these static language tables.
    throw UnimplementedError(
      'addOrUpdate() is not supported for language-specific tables.',
    );
  }

  @override
  Future<void> remove(String id) async {
    // We do not support deletions on these static language tables.
    throw UnimplementedError(
      'remove() is not supported for language-specific tables.',
    );
  }
}
