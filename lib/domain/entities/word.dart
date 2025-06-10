// lib/domain/entities/word.dart

enum WordType { normal, custom }

class Word {
  final String id;
  final String text;
  final String? translation;
  final String? sentence;
  final WordType type;

  Word({
    required this.id,
    required this.text,
    this.translation,
    this.sentence,
    this.type = WordType.normal,
  });

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as String,
      text: map['text'] as String,
      translation: map['translation'] as String?,
      sentence: map['sentence'] as String?,
      type: (map['type'] as String?) == 'custom'
          ? WordType.custom
          : WordType.normal,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'translation': translation,
      'sentence': sentence,
      'type': type == WordType.custom ? 'custom' : 'normal',
    };
  }
}
