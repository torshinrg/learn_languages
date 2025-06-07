import '../entities/custom_word.dart';

/// Stores and retrieves user-added custom words.
abstract class ICustomWordRepository {
  Future<List<CustomWord>> fetchAll();

  /// Fetch words for a specific [languageCode].
  Future<List<CustomWord>> fetchByLanguage(String languageCode);

  Future<void> add(CustomWord word);
  Future<void> remove(String id);
}
