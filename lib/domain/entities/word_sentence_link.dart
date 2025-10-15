
import '../../core/schema_fields.dart';

class WordSentenceLink {
  final String id;
  final String wordId;
  final String sentenceId;

  WordSentenceLink({
    required this.id,
    required this.wordId,
    required this.sentenceId,
  });

  factory WordSentenceLink.fromMap(Map<String, dynamic> map) {
    final wKey = SchemaFields.linkWordRef;
    final sKey = SchemaFields.linkSentenceRef;
    return WordSentenceLink(
      id: map['\$id'] as String,
      wordId: (map[wKey] ?? map['wordId'] ?? map['word']) as String,
      sentenceId: (map[sKey] ?? map['sentenceId'] ?? map['sentence']) as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wordId': wordId,
      'sentenceId': sentenceId,
    };
  }
}
