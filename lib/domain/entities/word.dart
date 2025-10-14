import '../../core/schema_fields.dart';

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
    final langKey = SchemaFields.wordLanguageRef;
    final textKey = SchemaFields.wordText;
    final rankKey = SchemaFields.wordRank;

    final id = map['\$id'] as String;
    final lang = (map[langKey] ?? map['languageId'] ?? map['language'] ?? map['langId'] ?? map['language_code'] ?? '') as String;
    final txt = (map[textKey] ?? map['text'] ?? map['word'] ?? map['value'] ?? '') as String;

    int rank = 0;
    final rawRank = (rankKey.isNotEmpty ? map[rankKey] : null) ?? map['frequencyRank'] ?? map['rank'] ?? map['freq'];
    if (rawRank is int) {
      rank = rawRank;
    } else if (rawRank is String) {
      rank = int.tryParse(rawRank) ?? 0;
    }

    return Word(id: id, languageId: lang, text: txt, frequencyRank: rank);
  }

  Map<String, dynamic> toMap() {
    return {
      'languageId': languageId,
      'text': text,
      'frequencyRank': frequencyRank,
    };
  }
}
