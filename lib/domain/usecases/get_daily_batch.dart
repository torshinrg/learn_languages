import 'package:learn_languages/domain/entities/word.dart';
import 'package:learn_languages/domain/repositories/i_word_repository.dart';

class GetDailyBatch {
  final IWordRepository _wordRepository;

  GetDailyBatch(this._wordRepository);

  Future<List<Word>> call(String languageId, int count) {
    return _wordRepository.fetchTopN(languageId, count);
  }
}