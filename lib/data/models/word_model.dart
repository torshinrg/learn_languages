// lib/data/models/word_model.dart

import '../../domain/entities/word.dart';

class WordModel {
  final String id;
  final String text;
  final String? translation;
  final String? sentence;
  final String type;

  WordModel({
    required this.id,
    required this.text,
    this.translation,
    this.sentence,
    required this.type,
  });

  factory WordModel.fromMap(Map<String, dynamic> m) => WordModel(
    id: m['id'] as String,
    text: m['text'] as String,
    translation: m['translation'] as String?,
    sentence: m['sentence'] as String?,
    type: m['type'] as String? ?? 'normal',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'translation': translation,
    'sentence': sentence,
    'type': type,
  };

  Word toEntity() => Word(
    id: id,
    text: text,
    translation: translation,
    sentence: sentence,
    type: type == 'custom' ? WordType.custom : WordType.normal,
  );
}
