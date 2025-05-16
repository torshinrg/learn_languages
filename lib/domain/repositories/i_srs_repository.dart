// lib/domain/repositories/i_srs_repository.dart

import '../entities/srs_data.dart';

/// Provides spaced-repetition scheduling operations.
abstract class ISRSRepository {
  /// Returns all SRS entries whose nextReview ≤ now.
  Future<List<SRSData>> fetchDue();

  /// Returns all SRS entries (both due and not yet due).
  Future<List<SRSData>> fetchAll();

  /// Schedule the next review for [wordId] with a SM-2 quality score (0–5).
  Future<void> scheduleNextWithQuality(String wordId, int quality);

  /// Schedule the next review for [wordId] based on [success].
  Future<void> scheduleNext(String wordId, bool success);
}
