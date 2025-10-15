import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens a lightweight local database for unauthenticated user data.
///
/// We keep this DB separate from any bundled content DB to avoid
/// migration/locking concerns. It only stores small, user-local tables
/// like `user_word_status` used while offline/anonymous.
Future<Database> openUserLocalDb() async {
  final dbDir = await getDatabasesPath();
  final dbPath = p.join(dbDir, 'user_local.db');

  return openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
      // Create a simple table for user word statuses.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_word_status (
          id TEXT,
          userId TEXT NOT NULL,
          wordId TEXT NOT NULL,
          status TEXT NOT NULL,
          UNIQUE(userId, wordId)
        );
      ''');
    },
  );
}

