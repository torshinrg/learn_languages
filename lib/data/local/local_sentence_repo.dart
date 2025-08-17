import 'package:learn_languages/domain/entities/sentence.dart';
import 'package:learn_languages/domain/repositories/i_sentence_repository.dart';
import 'package:sqflite/sqflite.dart';

class LocalSentenceRepository implements ISentenceRepository {
  final Database _db;

  LocalSentenceRepository(this._db);

  @override
  Future<List<Sentence>> fetchByWord(String wordId) {
    throw UnimplementedError();
  }
}