// lib/data/local/local_word_repo.dart

import 'package:sqflite/sqflite.dart';
import '../models/word_model.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/i_word_repository.dart';

class LocalWordRepository implements IWordRepository {
  final Database db;
  static const _table = 'words';

  LocalWordRepository(this.db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS $_table(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        translation TEXT,
        sentence TEXT,
        type TEXT NOT NULL
      );
    ''');
  }

  @override
  Future<List<Word>> fetchAll() async {
    final rows = await db.query(_table);
    return rows.map((r) => WordModel.fromMap(r).toEntity()).toList();
  }

  @override
  Future<void> addOrUpdate(Word word) async {
    final model = WordModel(
      id: word.id,
      text: word.text,
      translation: word.translation,
      sentence: word.sentence,
      type: word.type == WordType.custom ? 'custom' : 'normal',
    );
    await db.insert(
      _table,
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> remove(String id) async {
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
