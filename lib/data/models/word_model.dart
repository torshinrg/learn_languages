import '../../domain/entities/word.dart';

class WordModel {
  final String id;
  final String text;
  WordModel({required this.id, required this.text});
  factory WordModel.fromMap(Map<String, dynamic> m) => WordModel(id: m['id'], text: m['text']);
  Map<String, dynamic> toMap() => {'id': id, 'text': text};
  Word toEntity() => Word(id: id, text: text);
}
