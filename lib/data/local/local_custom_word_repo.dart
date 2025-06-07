import 'package:sqflite/sqflite.dart';
import '../../domain/entities/custom_word.dart';
import '../../domain/repositories/i_custom_word_repository.dart';

class LocalCustomWordRepository implements ICustomWordRepository {
  final Database db;
  static const _table = 'custom_words';

  LocalCustomWordRepository(this.db) {
    _init();
  }

  Future<void> _init() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_table(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL
      );
    ''');

    final cols = await db.rawQuery('PRAGMA table_info($_table)');
    final hasLang = cols.any((c) => c['name'] == 'language_code');
    if (!hasLang) {
      await db.execute('ALTER TABLE $_table ADD COLUMN language_code TEXT');
    }
  }

  @override
  Future<void> add(CustomWord word) => db.insert(
        _table,
        word.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  @override
  Future<List<CustomWord>> fetchAll() async {
    final rows = await db.query(_table);
    return rows.map((m) => CustomWord.fromMap(m)).toList();
  }

  @override
  Future<List<CustomWord>> fetchByLanguage(String languageCode) async {
    final rows = await db.query(
      _table,
      where: 'language_code = ?',
      whereArgs: [languageCode],
    );
    return rows.map((m) => CustomWord.fromMap(m)).toList();
  }

  @override
  Future<void> remove(String id) =>
      db.delete(_table, where: 'id = ?', whereArgs: [id]);
}
