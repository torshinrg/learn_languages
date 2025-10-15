
class UserSentenceTask {
  final String id;
  final String userId;
  final String sentenceTaskId;
  final bool completed;
  final String? response;
  final DateTime? completedAt;

  UserSentenceTask({
    required this.id,
    required this.userId,
    required this.sentenceTaskId,
    required this.completed,
    this.response,
    this.completedAt,
  });

  factory UserSentenceTask.fromMap(Map<String, dynamic> map) {
    return UserSentenceTask(
      id: map['\$id'] as String,
      userId: map['userId'] as String,
      sentenceTaskId: map['sentenceTaskId'] as String,
      completed: map['completed'] as bool,
      response: map['response'] as String?,
      completedAt: map['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completedAt'] as int)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sentenceTaskId': sentenceTaskId,
      'completed': completed,
      'response': response,
      'completedAt': completedAt?.millisecondsSinceEpoch,
    };
  }
}
