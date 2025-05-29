class CustomWord {
  final String id;
  final String text;

  CustomWord({required this.id, required this.text});

  factory CustomWord.fromMap(Map<String, dynamic> m) =>
      CustomWord(id: m['id'] as String, text: m['text'] as String);

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
      };
}
