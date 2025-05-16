// get_due_reviews.dart
import '../entities/word.dart';
import '../repositories/i_srs_repository.dart';
import '../repositories/i_word_repository.dart';

class GetDueReviews {
  final IWordRepository words;
  final ISRSRepository srs;
  GetDueReviews(this.words, this.srs);

  Future<List<Word>> call() async {
    final due = await srs.fetchDue();
    final all = await words.fetchAll();
    return all.where((w) => due.any((s) => s.wordId == w.id)).toList();
  }
}
