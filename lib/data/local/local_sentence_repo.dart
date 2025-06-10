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

    List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(sql, [pattern]);
    } catch (e) {
      return [];
    }

    return rows.map((r) => Sentence.fromMap(r)).toList();
  }
}
