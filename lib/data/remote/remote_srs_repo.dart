import '../../core/constants.dart';
import '../../domain/entities/srs_data.dart';
import '../../domain/repositories/i_srs_repository.dart';
import 'appwrite_service.dart';
import 'appwrite_utils.dart';

class RemoteSRSRepository implements ISRSRepository {
  RemoteSRSRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<SRSData>> fetchDue() async {
    final queries = AppwriteUtils.buildFilters({
      'next_review<=': DateTime.now().millisecondsSinceEpoch,
    });
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSrs,
      queries: queries,
    );
    return docs.map((d) => SRSData.fromMap(d.data)).toList();
  }

  @override
  Future<List<SRSData>> fetchAll() async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSrs,
    );
    return docs.map((d) => SRSData.fromMap(d.data)).toList();
  }

  Future<SRSData?> _getByWord(String wordId) async {
    final queries = AppwriteUtils.buildFilters({'word_id': wordId});
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSrs,
      queries: queries,
    );
    if (docs.isEmpty) return null;
    return SRSData.fromMap(docs.first.data);
  }

  @override
  Future<void> scheduleNext(String wordId, bool success) async {
    final existing = await _getByWord(wordId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (existing == null) {
      final data = SRSData(
        wordId: wordId,
        interval: kInitialIntervalDays,
        easiness: kInitialEasiness,
        repetition: 1,
        nextReview: today.add(const Duration(days: kInitialIntervalDays)),
      );
      await _service.createDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteSrs,
        documentId: wordId,
        data: data.toMap(),
      );
      return;
    }
    final newReps = success ? existing.repetition + 1 : 0;
    final newEf = success ? existing.easiness : existing.easiness;
    final newInterval = newReps == 1
        ? kInitialIntervalDays
        : newReps == 2
            ? 6
            : (existing.interval * newEf).ceil();
    final nextReview = today.add(Duration(days: newInterval));
    await _service.updateDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSrs,
      documentId: wordId,
      data: {
        'repetition': newReps,
        'easiness': newEf,
        'interval': newInterval,
        'next_review': nextReview.millisecondsSinceEpoch,
      },
    );
  }

  @override
  Future<void> scheduleNextWithQuality(String wordId, int quality) async {
    final existing = await _getByWord(wordId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (existing == null) {
      final data = SRSData(
        wordId: wordId,
        interval: kInitialIntervalDays,
        easiness: kInitialEasiness,
        repetition: 1,
        nextReview: today.add(const Duration(days: kInitialIntervalDays)),
      );
      await _service.createDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteSrs,
        documentId: wordId,
        data: data.toMap(),
      );
      return;
    }
    final newEf = (existing.easiness +
            (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
        .clamp(1.3, double.infinity);
    final newRep = quality < 3 ? 0 : existing.repetition + 1;
    final newInterval = newRep == 0
        ? kInitialIntervalDays
        : newRep == 1
            ? kInitialIntervalDays
            : newRep == 2
                ? 6
                : (existing.interval * newEf).ceil();
    final nextReview = today.add(Duration(days: newInterval));
    await _service.updateDocument(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteSrs,
      documentId: wordId,
      data: {
        'easiness': newEf,
        'repetition': newRep,
        'interval': newInterval,
        'next_review': nextReview.millisecondsSinceEpoch,
      },
    );
  }
}
