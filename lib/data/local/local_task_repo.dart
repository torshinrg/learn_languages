import 'package:learn_languages/domain/entities/task.dart';
import 'package:learn_languages/domain/repositories/i_task_repository.dart';
import 'package:sqflite/sqflite.dart';

class LocalTaskRepository implements ITaskRepository {
  final Database _db;

  LocalTaskRepository(this._db);

  @override
  Future<List<Task>> fetchBySentence(
    String sentenceId, {
    String? sentenceGroupId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Task>> fetchAllSentenceTasks() {
    throw UnimplementedError();
  }
}
