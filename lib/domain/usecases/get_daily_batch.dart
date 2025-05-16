// get_daily_batch.dart
import '../entities/word.dart';
import '../repositories/i_srs_repository.dart';
import '../repositories/i_word_repository.dart';

class GetDailyBatch {
  final IWordRepository words;
  final ISRSRepository srs;
  GetDailyBatch(this.words, this.srs);

  Future<List<Word>> call(int count) async {
    final due = await srs.fetchDue();
    final all = await words.fetchAll();
    final dueWords = all.where((w) => due.any((s) => s.wordId == w.id)).toList();
    if (dueWords.length >= count) return dueWords.take(count).toList();
    final fresh = all.where((w) => dueWords.every((d) => d.id != w.id)).take(count - dueWords.length);
    return [...dueWords, ...fresh];
  }
}
