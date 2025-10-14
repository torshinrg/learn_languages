class CustomWord {
  final String id;
  final String text;

  /// Language code for this custom word (e.g. 'en', 'es').
  final String languageCode;

  CustomWord({
    required this.id,
    required this.text,
    required this.languageCode,
  });

  factory CustomWord.fromMap(Map<String, dynamic> m) => CustomWord(
        id: m['id'] as String,
        text: m['text'] as String,
        languageCode: (m['language_code'] as String?) ?? 'und',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'language_code': languageCode,
      };
}
