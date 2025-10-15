
class SentenceTask {
  final String id;
  final String sentenceId;
  final String taskId;

  SentenceTask({
    required this.id,
    required this.sentenceId,
    required this.taskId,
  });

  factory SentenceTask.fromMap(Map<String, dynamic> map) {
    return SentenceTask(
      id: map['\$id'] as String,
      sentenceId: map['sentenceId'] as String,
      taskId: map['taskId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sentenceId': sentenceId,
      'taskId': taskId,
    };
  }
}
