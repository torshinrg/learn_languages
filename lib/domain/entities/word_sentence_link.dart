
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
    return WordSentenceLink(
      id: map['\$id'] as String,
      wordId: map['wordId'] as String,
      sentenceId: map['sentenceId'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wordId': wordId,
      'sentenceId': sentenceId,
    };
  }
}
