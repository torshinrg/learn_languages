// test/local_srs_repo_smoke_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_languages/data/local/local_srs_repo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';



void main() {
  group('LocalSRSRepository smoke tests', () {
    late Database db;
    late LocalSRSRepository repo;

    setUpAll(() async {
      // 1) Initialize FFI for sqflite in tests
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      // 2) Open an in-memory database with our SRS table schema
      db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE srs_data (
                word_id TEXT PRIMARY KEY,
                interval INTEGER,
                easiness REAL,
                repetition INTEGER,
                next_review INTEGER
              );
            ''');
          },
        ),
      );

      repo = LocalSRSRepository(db);
    });

    tearDownAll(() async {
      await db.close();
    });

    test('back-dated entry is due immediately', () async {
      await db.insert('srs_data', {
        'word_id': 'foo',
        'interval': 1,
        'easiness': 2.5,
        'repetition': 1,
        'next_review': 0,
      });
      final due = await repo.fetchDue();
      expect(due.map((e) => e.wordId), contains('foo'));
    });

    test('scheduleNext does NOT immediately make a new review due', () async {
      await repo.scheduleNext('bar', true);
      final due = await repo.fetchDue();
      expect(due.map((e) => e.wordId), isNot(contains('bar')));
    });

    test('manual back-date of scheduled review makes it due', () async {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;

      await db.update(
        'srs_data',
        {'next_review': yesterday},
        where: 'word_id = ?',
        whereArgs: ['bar'],
      );
      final due = await repo.fetchDue();
      expect(due.map((e) => e.wordId), contains('bar'));
    });
  });
}
