// lib/core/di.dart

import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/local/local_audio_repo.dart';
import '../data/local/local_sentence_repo.dart';
import '../data/local/local_srs_repo.dart';
import '../data/local/local_word_repo.dart';

import '../domain/repositories/i_audio_repository.dart';
import '../domain/repositories/i_sentence_repository.dart';
import '../domain/repositories/i_srs_repository.dart';
import '../domain/repositories/i_word_repository.dart';

import '../services/audio_check_service.dart';
import '../services/notification_service.dart';
import '../services/srs_service.dart';
import '../services/learning_service.dart';
import 'constants.dart';

final GetIt getIt = GetIt.instance;

/// Call this before runApp()
Future<void> setupLocator() async {
  final db = await _initDatabase();
  getIt.registerSingleton<Database>(db);

  // repositories
  getIt.registerLazySingleton<IWordRepository>(() => LocalWordRepository(db));
  getIt.registerLazySingleton<ISentenceRepository>(() => LocalSentenceRepository(db));
  getIt.registerLazySingleton<IAudioRepository>(() => LocalAudioRepository(db));
  getIt.registerLazySingleton<ISRSRepository>(() => LocalSRSRepository(db));

  // services
  getIt.registerLazySingleton<SRSService>(() => SRSService(getIt<ISRSRepository>()));
  getIt.registerLazySingleton<LearningService>(() => LearningService(
    wordRepo: getIt<IWordRepository>(),
    sentenceRepo: getIt<ISentenceRepository>(),
    srsRepo: getIt<ISRSRepository>(),
    audioRepo: getIt<IAudioRepository>(),
  ));
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<AudioCheckService>(() => AudioCheckService());

}

Future<Database> _initDatabase() async {
  final docsDir = await getApplicationDocumentsDirectory();
  final path = join(docsDir.path, kDbFileName);


  if (!File(path).existsSync()) {
    final data = await rootBundle.load('assets/databases/spanish_app.db');
    final bytes = data.buffer.asUint8List();
    await File(path).writeAsBytes(bytes);
  }
  // Copy prebuilt DB if needed...
  final db = await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS srs_data (
          word_id TEXT PRIMARY KEY,
          interval INTEGER,
          easiness REAL,
          repetition INTEGER,
          next_review INTEGER
        );
      ''');

      // 1) Create the FTS5 virtual table
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS sentences_fts
        USING fts4(
          spanish, 
          english,
          audio UNINDEXED
        );
      ''');

      // 2) Populate FTS from existing sentences
      await db.execute('''
        INSERT INTO sentences_fts(rowid, spanish, english, audio)
        SELECT rowid, spanish, english, audio FROM sentences;
      ''');

      // 3) Triggers to keep FTS in sync
      await db.execute('''
        CREATE TRIGGER sentences_ai AFTER INSERT ON sentences BEGIN
          INSERT INTO sentences_fts(rowid, spanish, english, audio)
          VALUES (new.rowid, new.spanish, new.english, new.audio);
        END;
      ''');
      await db.execute('''
        CREATE TRIGGER sentences_ad AFTER DELETE ON sentences BEGIN
          DELETE FROM sentences_fts WHERE rowid = old.rowid;
        END;
      ''');
      await db.execute('''
        CREATE TRIGGER sentences_au AFTER UPDATE ON sentences BEGIN
          INSERT INTO sentences_fts(sentences_fts, rowid, spanish, english, audio)
          VALUES('delete', old.rowid, old.spanish, old.english, old.audio);
          INSERT INTO sentences_fts(rowid, spanish, english, audio)
          VALUES (new.rowid, new.spanish, new.english, new.audio);
        END;
      ''');
    },
    onOpen: (db) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS srs_data (
          word_id TEXT PRIMARY KEY,
          interval INTEGER,
          easiness REAL,
          repetition INTEGER,
          next_review INTEGER
        );
      ''');
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS sentences_fts
        USING fts4(
          spanish, 
          english,
          audio UNINDEXED          
        );
      ''');
    },
  );

  return db;
}

