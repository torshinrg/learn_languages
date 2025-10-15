/// Centralized schema field names with runtime-detectable overrides.
///
/// Defaults are conservative guesses; `AppwriteSchemaProbe` updates them
/// at runtime by inspecting sample documents in public collections.
class SchemaFields {
  // Languages collection fields
  static String languageCode = 'code';

  // Words collection → field referencing language
  static String wordLanguageRef = 'languageId'; // e.g. 'language', 'langId'
  // Words fields (optional, detected)
  static String wordText = 'text'; // e.g. 'word', 'value'
  static String wordRank = ''; // e.g. 'frequencyRank', 'rank', may be empty
  // Words → sentences relation field (list of sentence IDs or refs)
  static String wordExamplesRef = 'example'; // e.g. 'examples', 'exampleSentences'

  // Sentences collection → field referencing language
  static String sentenceLanguageRef = 'languageId';
  // Sentences collection → grouping field for cross-language equivalents
  static String sentenceGroupId = 'group_id';

  // Word-sentence links collection fields
  static String linkWordRef = 'wordId';
  static String linkSentenceRef = 'sentenceId';

  // Utility to update if a preferred key exists in the map
  static String detectKey(Map<String, dynamic> map, List<String> candidates,
      {String? fallback}) {
    for (final k in candidates) {
      if (map.containsKey(k)) return k;
    }
    return fallback ?? candidates.first;
  }
}
