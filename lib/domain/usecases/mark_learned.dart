// mark_learned.dart
import '../repositories/i_srs_repository.dart';

class MarkLearned {
  final ISRSRepository srs;
  MarkLearned(this.srs);

  Future<void> call(String wordId, int quality) {
    return srs.scheduleNextWithQuality(wordId, quality);
  }
}
