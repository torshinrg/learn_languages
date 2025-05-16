// lib/domain/entities/sentence.dart
class Sentence {
  final String id;
  final String idEnglish;
  final String spanish;
  final String english;
  final bool audio;

  Sentence({
    required this.id,
    required this.idEnglish,
    required this.spanish,
    required this.english,
    required this.audio,
  });

  factory Sentence.fromMap(Map<String, dynamic> map) {
    return Sentence(
      id: map['id'] as String,
      idEnglish: map['id_english'] as String,
      spanish: map['spanish'] as String,
      english: map['english'] as String,
      audio: (map['audio'] as int) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_english': idEnglish,
      'spanish': spanish,
      'english': english,
      'audio': audio ? 1 : 0,
    };
  }
}
