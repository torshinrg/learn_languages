import 'package:learn_languages/domain/entities/word.dart';
import 'package:learn_languages/domain/repositories/i_word_repository.dart';
import 'package:sqflite/sqflite.dart';

class LocalWordRepository implements IWordRepository {
  final Database _db;

  LocalWordRepository(this._db);

  @override
  Future<Word> fetchById(String wordId) {
    throw UnimplementedError();
  }

  @override
  Future<List<Word>> fetchTopN(String languageId, int n) {
    throw UnimplementedError();
  }
}