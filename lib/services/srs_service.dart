// lib/services/srs_service.dart

import '../domain/entities/srs_data.dart';
import '../domain/repositories/i_srs_repository.dart';

class SRSService {
  final ISRSRepository _repo;
  SRSService(this._repo);

  /// Fetch raw SRS entries due now.
  Future<List<SRSData>> fetchDueData() => _repo.fetchDue();

  /// Fetch *all* SRS entries (scheduled).
  Future<List<SRSData>> fetchAllData() => _repo.fetchAll();

  /// Convenience: mark result for a word.
  Future<void> markResult(String wordId, bool success) {
    return _repo.scheduleNext(wordId, success);
  }
}
