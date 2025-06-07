// lib/data/local/local_sentence_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../core/app_language.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/repositories/i_sentence_repository.dart';

class LocalSentenceRepository implements ISentenceRepository {
  final Database db;
  LocalSentenceRepository(this.db);

  @override
  Future<List<Sentence>> fetchAll() async {
    final rows = await db.query('sentences');
    return rows.map((r) => Sentence.fromMap(r)).toList();
  }

  @override
  Future<List<Sentence>> fetchForWord(
    String wordText,
    String languageCode, {
    int? limit,
  }) async {
    final langEnum = AppLanguageExtension.fromCode(languageCode);
    if (langEnum == null) {
      print(
        '⚠️ [LocalSentenceRepo] Unsupported languageCode="$languageCode". '
        'Allowed: ${AppLanguage.values.map((e) => e.code).join(", ")}',
      );
      return [];
    }

    final column = '${langEnum.name}_text'; // e.g. "english_text"
    final audioColumn = '${langEnum.name}_audio';
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final sql = '''
      SELECT *
      FROM sentences
      WHERE $column LIKE ? AND $audioColumn = 1
      ORDER BY RANDOM()
      $limitClause
    ''';
    final pattern = '%$wordText%';

    print('🔍 [LocalSentenceRepo] Querying sentences:');
    print('    languageCode="$languageCode" → column="$column"');
    print('    SQL →\n$sql');
    print('    pattern="$pattern"');

    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(sql, [pattern]);
    } catch (e) {
      print('❌ [LocalSentenceRepo] ERROR rawQuery: $e');
      return [];
    }

    print(
      '🔍 [LocalSentenceRepo] Found ${rows.length} row(s) for '
      '"$wordText" in column="$column"',
    );
    return rows.map((r) => Sentence.fromMap(r)).toList();
  }
}
