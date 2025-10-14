
enum TermType {
  word,
  sentence,
}

class UserVocabulary {
  final String id;
  final String userId;
  final TermType termType;
  final String referenceId;
  final DateTime addedAt;

  UserVocabulary({
    required this.id,
    required this.userId,
    required this.termType,
    required this.referenceId,
    required this.addedAt,
  });

  factory UserVocabulary.fromMap(Map<String, dynamic> map) {
    return UserVocabulary(
      id: map['\$id'] as String,
      userId: map['userId'] as String,
      termType: TermType.values.byName(map['termType'] as String),
      referenceId: map['referenceId'] as String,
      addedAt: DateTime.fromMillisecondsSinceEpoch(map['addedAt'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'termType': termType.name,
      'referenceId': referenceId,
      'addedAt': addedAt.millisecondsSinceEpoch,
    };
  }
}
