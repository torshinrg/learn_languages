// File: lib/domain/repositories/i_task_repository.dart

import '../entities/task.dart';

/// Defines methods to fetch tasks and record history.
abstract class ITaskRepository {
  /// Returns all tasks of [taskType] for the given [locale].
  Future<List<Task>> fetchTasksByType(String taskType, String locale);

  /// Record that the user performed [taskId] on [sentenceId] (or null if screen-level)
  /// at current timestamp, with an optional [result].
  Future<void> saveTaskHistory({
    required String taskId,
    String? sentenceId,
    String? result,
  });
}
