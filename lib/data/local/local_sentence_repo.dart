// lib/data/local/local_sentence_repo.dart

import 'package:sqflite/sqflite.dart';
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
  Future<List<Sentence>> fetchForWord(String wordText, {int? limit}) async {
    // 1) Use FTS table directly (no alias) with prefix search
    final ftsQuery   = '$wordText*';
    final limitClause = limit != null ? 'LIMIT $limit' : '';

    final sql = '''
      SELECT s.*
      FROM sentences AS s
      JOIN sentences_fts
        ON s.rowid = sentences_fts.rowid
      WHERE sentences_fts MATCH ?
      ORDER BY s.audio DESC, RANDOM()
      $limitClause
    ''';

    // 2) Run rawQuery with the FTS pattern
    final rows = await db.rawQuery(sql, [ftsQuery]);

    // 3) Map results into Sentence objects (including new audio field)
    final results = rows.map((r) => Sentence.fromMap(r)).toList();

    return results;
  }
}
