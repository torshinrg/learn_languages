import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/local_custom_word_repo.dart';
import '../data/local/local_srs_repo.dart';
import '../data/remote/appwrite_service.dart';
import '../core/constants.dart';

class DataMigrationService {
  DataMigrationService({
    required this.prefs,
    required this.localCustomRepo,
    required this.localSrsRepo,
    required this.appwrite,
  });

  final SharedPreferences prefs;
  final LocalCustomWordRepository localCustomRepo;
  final LocalSRSRepository localSrsRepo;
  final AppwriteService appwrite;

  static const _flag = 'cloud_migrated';

  Future<void> migrateIfNeeded() async {
    final done = prefs.getBool(_flag) ?? false;
    if (done) return;

    final words = await localCustomRepo.fetchAll();
    for (final word in words) {
      await appwrite.createDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteCustomWords,
        documentId: word.id,
        data: word.toMap(),
      );
    }

    final srs = await localSrsRepo.fetchAll();
    for (final data in srs) {
      await appwrite.createDocument(
        databaseId: kAppwriteDatabaseId,
        collectionId: kAppwriteSrs,
        documentId: data.wordId,
        data: data.toMap(),
      );
    }

    await prefs.setBool(_flag, true);
  }
}
