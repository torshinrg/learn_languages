// lib/domain/repositories/i_word_repository.dart

import '../entities/word.dart';

abstract class IWordRepository {
  Future<List<Word>> fetchAll();
  Future<void> addOrUpdate(Word word);
  Future<void> remove(String id);
}
