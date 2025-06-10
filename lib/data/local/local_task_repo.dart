// File: lib/data/local/local_task_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/i_task_repository.dart';
import 'package:uuid/uuid.dart';

class LocalTaskRepository implements ITaskRepository {
  final Database db;
  static const _tasksTable = 'tasks';
  static const _historyTable = 'task_history';

  LocalTaskRepository(this.db) {
    _createTablesIfNeeded();
  }

  Future<void> _createTablesIfNeeded() async {
    // 1) Create tasks table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tasksTable (
        id TEXT PRIMARY KEY,
        description TEXT NOT NULL,
        locale TEXT NOT NULL,
        task_type TEXT NOT NULL
      );
    ''');

    // 2) Create history table if it doesn't exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_historyTable (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        sentence_id TEXT,
        timestamp INTEGER NOT NULL,
        result TEXT
      );
    ''');
  }

  @override
  Future<List<Task>> fetchTasksByType(String taskType, String locale) async {
    final rows = await db.query(
      _tasksTable,
      where: 'task_type = ? AND locale = ?',
      whereArgs: [taskType, locale],
    );
    return rows.map((m) => Task.fromMap(m)).toList();
  }

  @override
  Future<void> saveTaskHistory({
    required String taskId,
    String? sentenceId,
    String? result,
  }) async {
    final id = const Uuid().v4();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      _historyTable,
      {
        'id': id,
        'task_id': taskId,
        'sentence_id': sentenceId,
        'timestamp': timestamp,
        'result': result,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
