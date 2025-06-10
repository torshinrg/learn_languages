// File: lib/domain/entities/task.dart

/// Represents a task defined in the database.
class Task {
  final String id;
  final String description;
  final String locale;
  final String taskType;

  Task({
    required this.id,
    required this.description,
    required this.locale,
    required this.taskType,
  });

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as String,
    description: map['description'] as String,
    locale: map['locale'] as String,
    taskType: map['task_type'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'description': description,
    'locale': locale,
    'task_type': taskType,
  };
}
