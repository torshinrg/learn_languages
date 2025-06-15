// File: lib/core/di.dart

import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:get_it/get_it.dart';
import 'package:learn_languages/data/local/local_custom_word_repo.dart';
import 'package:learn_languages/domain/repositories/i_custom_word_repository.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/local/local_audio_repo.dart';
import '../data/local/local_sentence_repo.dart';
import '../data/local/local_srs_repo.dart';
import '../data/local/local_word_repo.dart';
import '../data/local/local_task_repo.dart';

import '../domain/repositories/i_audio_repository.dart';
import '../domain/repositories/i_sentence_repository.dart';
import '../domain/repositories/i_srs_repository.dart';
import '../domain/repositories/i_word_repository.dart';
import '../domain/repositories/i_task_repository.dart';

import '../services/audio_check_service.dart';
import '../services/notification_service.dart';
import '../services/srs_service.dart';
import '../services/learning_service.dart';

import 'constants.dart';
import 'app_language.dart';

final GetIt getIt = GetIt.instance;

/// Call this before runApp()
Future<void> setupLocator() async {
  final db = await _initDatabase();
  getIt.registerSingleton<Database>(db);

  // Repositories
  getIt.registerLazySingleton<IWordRepository>(() => LocalWordRepository(db));
  getIt.registerLazySingleton<ISentenceRepository>(
    () => LocalSentenceRepository(db),
  );
  getIt.registerLazySingleton<IAudioRepository>(() => LocalAudioRepository(db));
  getIt.registerLazySingleton<ISRSRepository>(() => LocalSRSRepository(db));
  getIt.registerLazySingleton<ICustomWordRepository>(
    () => LocalCustomWordRepository(getIt<Database>()),
  );
  getIt.registerLazySingleton<ITaskRepository>(() => LocalTaskRepository(db));

  // Services
  getIt.registerLazySingleton<SRSService>(
    () => SRSService(getIt<ISRSRepository>()),
  );
  getIt.registerLazySingleton<LearningService>(
    () => LearningService(
      wordRepo: getIt<IWordRepository>(),
      sentenceRepo: getIt<ISentenceRepository>(),
      srsRepo: getIt<ISRSRepository>(),
      audioRepo: getIt<IAudioRepository>(),
      customRepo: getIt<ICustomWordRepository>(),
    ),
  );
  getIt.registerLazySingleton<NotificationService>(() => NotificationService());
  getIt.registerLazySingleton<AudioCheckService>(() => AudioCheckService());
}

Future<Database> _initDatabase() async {
  if (kIsWeb) {
    // No path provider on the web, so use an in-memory database.
    return openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  final docsDir = await getApplicationDocumentsDirectory();
  final path = join(docsDir.path, kDbFileName);

  if (!File(path).existsSync()) {
    final data = await rootBundle.load('assets/databases/$kDbFileName');
    final bytes = data.buffer.asUint8List();
    await File(path).writeAsBytes(bytes);
  }

  final db = await openDatabase(
    path,
    version: 1,
    onCreate: _onCreate,
    onOpen: _onOpen,
  );

  return db;
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute('''
        CREATE TABLE IF NOT EXISTS srs_data (
          word_id TEXT PRIMARY KEY,
          interval INTEGER,
          easiness REAL,
          repetition INTEGER,
          next_review INTEGER
        );
      ''');

  final languageColumns =
      AppLanguage.values.map((lang) => '${lang.name}_text').toList();
  final ftsColumns = languageColumns.join(', ');

  await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS sentences_fts
        USING fts4(
          $ftsColumns,
          audio UNINDEXED
        );
      ''');

  final selectColumns = languageColumns.join(', ');
  await db.execute('''
        INSERT INTO sentences_fts(rowid, $ftsColumns, audio)
        SELECT rowid, $selectColumns, audio
        FROM sentences;
      ''');

  await db.execute('''
        CREATE TRIGGER sentences_ai AFTER INSERT ON sentences BEGIN
          INSERT INTO sentences_fts(rowid, $ftsColumns, audio)
          VALUES (
            new.rowid,
            ${languageColumns.map((col) => 'new.$col').join(', ')},
            new.audio
          );
        END;
      ''');
  await db.execute('''
        CREATE TRIGGER sentences_ad AFTER DELETE ON sentences BEGIN
          DELETE FROM sentences_fts WHERE rowid = old.rowid;
        END;
      ''');
  await db.execute('''
        CREATE TRIGGER sentences_au AFTER UPDATE ON sentences BEGIN
          INSERT INTO sentences_fts(sentences_fts, rowid, $ftsColumns, audio)
          VALUES (
            'delete',
            old.rowid,
            ${languageColumns.map((col) => 'old.$col').join(', ')},
            old.audio
          );
          INSERT INTO sentences_fts(rowid, $ftsColumns, audio)
          VALUES (
            new.rowid,
            ${languageColumns.map((col) => 'new.$col').join(', ')},
            new.audio
          );
        END;
      ''');

  await db.execute('''
        CREATE TABLE IF NOT EXISTS tasks(
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          task_type TEXT NOT NULL,
          sentence_id TEXT,
          user_result TEXT,
          completed INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
}

Future<void> _onOpen(Database db) async {
  await db.execute('''
        CREATE TABLE IF NOT EXISTS tasks(
          id TEXT PRIMARY KEY,
          description TEXT NOT NULL,
          task_type TEXT NOT NULL,
          sentence_id TEXT,
          user_result TEXT,
          completed INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
}
