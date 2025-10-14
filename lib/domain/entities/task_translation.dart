
class TaskTranslation {
  final String id;
  final String taskId;
  final String languageCode;
  final String promptTemplate;

  TaskTranslation({
    required this.id,
    required this.taskId,
    required this.languageCode,
    required this.promptTemplate,
  });

  factory TaskTranslation.fromMap(Map<String, dynamic> map) {
    return TaskTranslation(
      id: map['\$id'] as String,
      taskId: map['taskId'] as String,
      languageCode: map['languageCode'] as String,
      promptTemplate: map['promptTemplate'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'languageCode': languageCode,
      'promptTemplate': promptTemplate,
    };
  }
}
