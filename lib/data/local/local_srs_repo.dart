// lib/data/local/local_srs_repo.dart

import 'package:sqflite/sqflite.dart';
import '../../domain/entities/srs_data.dart';
import '../../domain/repositories/i_srs_repository.dart';

class LocalSRSRepository implements ISRSRepository {
  final Database db;
  LocalSRSRepository(this.db);

  @override
  Future<List<SRSData>> fetchDue() async {
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final rows = await db.query(
      'srs_data',
      where: 'next_review <= ?',
      whereArgs: [nowMillis],
    );
    return rows.map((r) => SRSData.fromMap(r)).toList();
  }

  @override
  Future<List<SRSData>> fetchAll() async {
    final rows = await db.query('srs_data');
    return rows.map((r) => SRSData.fromMap(r)).toList();
  }

  @override
  Future<void> scheduleNext(String wordId, bool success) async {
    final existing = await db.query(
      'srs_data',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    // Compute today at midnight
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    if (existing.isEmpty) {
      // First time: insert with REPLACE on conflict
      final intervalDays = 1;
      final nextReviewDate = todayMidnight.add(Duration(days: intervalDays));
      final data = SRSData(
        wordId: wordId,
        interval: intervalDays,
        easiness: 2.5,
        repetition: 1,
        nextReview: nextReviewDate,
      );
      await db.insert(
        'srs_data',
        data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      // SM-2 algorithm → update existing row
      final old = SRSData.fromMap(existing.first);
      final newReps = success ? old.repetition + 1 : 0;
      final newEf = success
          ? (old.easiness + (0.1 - (5 - 5) * (0.08 + (5 - 5) * 0.02)))
          : old.easiness;
      final newInterval = newReps == 1
          ? 1
          : newReps == 2
          ? 6
          : (old.interval * newEf).ceil();
      final nextReviewDate = todayMidnight.add(Duration(days: newInterval));

      await db.update(
        'srs_data',
        {
          'repetition': newReps,
          'easiness': newEf,
          'interval': newInterval,
          'next_review': nextReviewDate.millisecondsSinceEpoch,
        },
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
    }
  }

  @override
  Future<void> scheduleNextWithQuality(String wordId, int quality) async {
    final existing = await db.query(
      'srs_data',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    if (existing.isEmpty) {
      // First review: also use REPLACE
      final intervalDays = 1;
      final nextReviewDate = todayMidnight.add(Duration(days: intervalDays));
      final data = SRSData(
        wordId: wordId,
        interval: intervalDays,
        easiness: 2.5,
        repetition: 1,
        nextReview: nextReviewDate,
      );
      await db.insert(
        'srs_data',
        data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final old = SRSData.fromMap(existing.first);

    // update EF, reps, interval...
    final newEf = (old.easiness +
        (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
        .clamp(1.3, double.infinity);
    final newRep = quality < 3 ? 0 : old.repetition + 1;
    final newInterval = newRep == 0
        ? 1
        : newRep == 1
        ? 1
        : newRep == 2
        ? 6
        : (old.interval * newEf).ceil();
    final nextReviewDate = todayMidnight.add(Duration(days: newInterval));

    await db.update(
      'srs_data',
      {
        'easiness': newEf,
        'repetition': newRep,
        'interval': newInterval,
        'next_review': nextReviewDate.millisecondsSinceEpoch,
      },
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }
}
