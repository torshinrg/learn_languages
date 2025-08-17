class Word {
  final String id;
  final String languageId;
  final String text;
  final int frequencyRank;

  Word({
    required this.id,
    required this.languageId,
    required this.text,
    required this.frequencyRank,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['\$id'] as String,
      languageId: map['languageId'] as String,
      text: map['text'] as String,
      frequencyRank: map['frequencyRank'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languageId': languageId,
      'text': text,
      'frequencyRank': frequencyRank,
    };
  }
}