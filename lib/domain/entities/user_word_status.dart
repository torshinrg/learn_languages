
enum WordStatus {
  New,
  inProgress,
  known,
}

class UserWordStatus {
  final String id;
  final String userId;
  final String wordId;
  final WordStatus status;

  UserWordStatus({
    required this.id,
    required this.userId,
    required this.wordId,
    required this.status,
  });

  factory UserWordStatus.fromMap(Map<String, dynamic> map) {
    return UserWordStatus(
      id: (map['\$id'] ?? map['id'] ?? '') as String,
      userId: map['userId'] as String,
      wordId: map['wordId'] as String,
      status: WordStatus.values.byName(map['status'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'wordId': wordId,
      'status': status.name,
    };
  }
}
