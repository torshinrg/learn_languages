// lib/domain/repositories/i_word_repository.dart

import '../entities/word.dart';

/// Provides access to word data.
abstract class IWordRepository {
  /// Fetch all words from the database.
  Future<List<Word>> fetchAll();
}
