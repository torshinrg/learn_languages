
class MaterialSentence {
  final String id;
  final String materialId;
  final String sentenceId;
  final int order;

  MaterialSentence({
    required this.id,
    required this.materialId,
    required this.sentenceId,
    required this.order,
  });

  factory MaterialSentence.fromMap(Map<String, dynamic> map) {
    return MaterialSentence(
      id: map['\$id'] as String,
      materialId: map['materialId'] as String,
      sentenceId: map['sentenceId'] as String,
      order: map['order'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'materialId': materialId,
      'sentenceId': sentenceId,
      'order': order,
    };
  }
}
