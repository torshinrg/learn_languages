// lib/data/local/local_word_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/i_word_repository.dart';

/// Local SQLite implementation of IWordRepository.
class LocalWordRepository implements IWordRepository {
  final Database db;
  LocalWordRepository(this.db);

  @override
  Future<List<Word>> fetchAll() async {
    final rows = await db.query('words');
    return rows.map((r) => Word.fromMap(r)).toList();
  }
}
