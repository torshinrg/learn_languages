import '../entities/custom_word.dart';

/// Stores and retrieves user-added custom words.
abstract class ICustomWordRepository {
  Future<List<CustomWord>> fetchAll();
  Future<void> add(CustomWord word);
  Future<void> remove(String id);
}
