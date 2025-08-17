class Sentence {
  final String id;
  final String languageId;
  final String content;
  final String? audioUrl;

  Sentence({
    required this.id,
    required this.languageId,
    required this.content,
    this.audioUrl,
  });

  factory Sentence.fromMap(Map<String, dynamic> map) {
    return Sentence(
      id: map['\$id'] as String,
      languageId: map['languageId'] as String,
      content: map['content'] as String,
      audioUrl: map['audioUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languageId': languageId,
      'content': content,
      'audioUrl': audioUrl,
    };
  }
}