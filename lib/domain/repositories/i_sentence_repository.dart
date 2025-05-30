// lib/domain/repositories/i_sentence_repository.dart

import '../entities/sentence.dart';

/// Provides access to sentence data.
abstract class ISentenceRepository {
  /// Fetch all sentences.
  Future<List<Sentence>> fetchAll();

  /// Fetch up to [limit] sentences containing [wordText] (case-insensitive),
  /// in random order. If [limit] is null, returns *all* matches.
  Future<List<Sentence>> fetchForWord(String wordText, {int? limit});
}
