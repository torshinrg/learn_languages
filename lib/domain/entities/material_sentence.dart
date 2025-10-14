import 'sentence.dart';

class MaterialSentence {
  final String id;
  final String materialId;
  final String sentenceId;
  final int order;
  final Sentence? sentence;

  MaterialSentence({
    required this.id,
    required this.materialId,
    required this.sentenceId,
    required this.order,
    this.sentence,
  });

  factory MaterialSentence.fromMap(Map<String, dynamic> map) {
    final sentenceRel = map['sentences'];
    Sentence? resolvedSentence;
    String sentenceId;
    if (sentenceRel is Map<String, dynamic>) {
      sentenceId = (sentenceRel['\$id'] ?? sentenceRel['id'] ?? '').toString();
      resolvedSentence = Sentence.fromMap(sentenceRel);
    } else if (sentenceRel is String) {
      sentenceId = sentenceRel;
    } else {
      sentenceId = (map['sentenceId'] ?? '').toString();
    }

    final materialRel = map['readingMaterials'];
    String materialId;
    if (materialRel is String) {
      materialId = materialRel;
    } else if (materialRel is Map<String, dynamic>) {
      materialId = (materialRel['\$id'] ?? materialRel['id'] ?? '').toString();
    } else {
      materialId = (map['materialId'] ?? '').toString();
    }

    return MaterialSentence(
      id: map['\$id'] as String,
      materialId: materialId,
      sentenceId: sentenceId,
      order: (map['order'] ?? map['position'] ?? 0) as int,
      sentence: resolvedSentence,
    );
  }

  Map<String, dynamic> toMap() {
    return {'materialId': materialId, 'sentenceId': sentenceId, 'order': order};
  }
}

class MaterialSentencePage {
  MaterialSentencePage({required this.items, required this.total});

  final List<MaterialSentence> items;
  final int total;
}
