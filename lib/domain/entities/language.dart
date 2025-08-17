
class Language {
  final String id;
  final String code;
  final String name;

  Language({
    required this.id,
    required this.code,
    required this.name,
  });

  factory Language.fromMap(Map<String, dynamic> map) {
    return Language(
      id: map['\$id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
    };
  }
}
