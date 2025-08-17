
enum MaterialType {
  book,
  article,
  news,
}

class ReadingMaterial {
  final String id;
  final String languageId;
  final String title;
  final MaterialType type;
  final String rawText;

  ReadingMaterial({
    required this.id,
    required this.languageId,
    required this.title,
    required this.type,
    required this.rawText,
  });

  factory ReadingMaterial.fromMap(Map<String, dynamic> map) {
    return ReadingMaterial(
      id: map['\$id'] as String,
      languageId: map['languageId'] as String,
      title: map['title'] as String,
      type: MaterialType.values.byName(map['type'] as String),
      rawText: map['rawText'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languageId': languageId,
      'title': title,
      'type': type.name,
      'rawText': rawText,
    };
  }
}
