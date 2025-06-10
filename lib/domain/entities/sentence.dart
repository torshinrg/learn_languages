// lib/domain/entities/sentence.dart

import 'package:learn_languages/core/app_language.dart';

class Sentence {
  /// A map from two-letter code (e.g. "en", "ru", "es", …) → the `<lang>_text` column
  final Map<String, String> textByCode;

  /// A map from two-letter code → the `<lang>_id` column
  final Map<String, String> idByCode;

  Sentence({required this.textByCode, required this.idByCode});

  /// Factory to build from a raw `Map<String, dynamic>` coming from SQLite.
  factory Sentence.fromMap(Map<String, dynamic> m) {
    final texts = <String, String>{};
    final ids = <String, String>{};

    // For every AppLanguage, pick out both `<name>_text` and `<name>_id`.
    for (var lang in AppLanguage.values) {
      final code = lang.code; // "en", "ru", "es", ...
      final name = lang.name; // "english", "russian", "spanish", ...

      // Read them as nullable String; if it’s null, default to empty string.
      final textKey = '${name}_text';
      final idKey = '${name}_id';

      final textVal = (m[textKey] as String?) ?? '';
      final idVal = (m[idKey] as String?) ?? '';

      texts[code] = textVal;
      ids[code] = idVal;
    }

    return Sentence(textByCode: texts, idByCode: ids);
  }

  /// Return the sentence text for a given two-letter code (e.g. "en" or "ru").
  /// If that language isn’t in the table, returns empty string.
  String text(String code) {
    return textByCode[code] ?? '';
  }

  /// Return the sentence’s unique ID for a given two-letter code (e.g. "en" or "ru").
  /// If that language/ID isn’t in the table, returns empty string.
  String id(String code) {
    return idByCode[code] ?? '';
  }
}
