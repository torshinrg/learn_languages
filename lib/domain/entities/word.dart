// lib/domain/entities/word.dart
class Word {
  final String id;
  final String text;

  Word({required this.id, required this.text});

  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      id: map['id'] as String,
      text: map['text'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
    };
  }
}
