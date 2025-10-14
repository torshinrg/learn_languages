import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/domain/repositories/i_user_word_status_repository.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';

class LocalUserWordStatusRepository implements IUserWordStatusRepository {
  final Database _db;

  LocalUserWordStatusRepository(this._db);

  @override
  Future<void> create(UserWordStatus status) async {
    final data = status.toMap();
    // Ensure we persist a stable local id for easier lookups
    data['id'] = '${status.userId}_${status.wordId}';
    await _db.insert(
      kTableUserWordStatus,
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(UserWordStatus status) async {
    await _db.update(
      kTableUserWordStatus,
      status.toMap(),
      where: '$kColumnUserId = ? AND $kColumnWordId = ?',
      whereArgs: [status.userId, status.wordId],
    );
  }

  @override
  Future<UserWordStatus> fetch(String userId, String wordId) async {
    final maps = await _db.query(
      kTableUserWordStatus,
      where: '$kColumnUserId = ? AND $kColumnWordId = ?',
      whereArgs: [userId, wordId],
    );

    if (maps.isNotEmpty) {
      return UserWordStatus.fromMap(maps.first);
    }
    throw Exception('UserWordStatus not found');
  }

  @override
  Future<List<UserWordStatus>> fetchByStatus(
      String userId, WordStatus status) async {
    final maps = await _db.query(
      kTableUserWordStatus,
      where: '$kColumnUserId = ? AND $kColumnStatus = ?',
      whereArgs: [userId, status.name],
    );

    return maps.map((map) => UserWordStatus.fromMap(map)).toList();
  }

  @override
  Future<int> count(String userId, WordStatus status) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) FROM $kTableUserWordStatus WHERE $kColumnUserId = ? AND $kColumnStatus = ?',
      [userId, status.name],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
