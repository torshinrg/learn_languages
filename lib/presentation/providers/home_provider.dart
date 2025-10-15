import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';
import '../../services/learning_service.dart';
import 'settings_provider.dart';
import '../../data/remote/appwrite_service.dart';

class HomeProvider extends ChangeNotifier {
  final LearningService _learningService;
  final SettingsProvider _settingsProvider;
  final AppwriteService _appwriteService;

  int _inProgressCount = 0;
  int _newWordsCount = 0;
  int _knownCount = 0;

  int get inProgressCount => _inProgressCount;
  int get newWordsCount => _newWordsCount;
  int get knownCount => _knownCount;

  bool get canStudy => _newWordsCount > 0;

  Future<void>? _refreshFuture;
  bool _refreshQueued = false;

  HomeProvider(
    this._learningService,
    this._settingsProvider,
    this._appwriteService,
  ) {
    _settingsProvider.addListener(refresh);
    refresh();
  }

  Future<void> refresh() async {
    if (_refreshFuture != null) {
      _refreshQueued = true;
      return;
    }
    await _runRefresh();
    while (_refreshQueued) {
      _refreshQueued = false;
      await _runRefresh();
    }
  }

  Future<void> _runRefresh() {
    final future = _doRefresh().whenComplete(() {
      _refreshFuture = null;
    });
    _refreshFuture = future;
    return future;
  }

  Future<void> _doRefresh() async {
    try {
      final user = await _appwriteService.account.get();
      // Ensure initial local seed for anonymous users
      final codes = _settingsProvider.learningLanguageCodes;
      final langCode = codes.isNotEmpty ? codes.first : 'en';
      try {
        await _learningService.ensureSeedIfEmpty(
          userId: user.$id,
          languageCode: langCode,
          seedCount: 100,
        );
      } on AppwriteException catch (e) {
        if (e.code == 400) {
          print(
            '[HomeProvider] 400 during seeding, retrying via fallback path',
          );
          await _learningService.ensureSeedIfEmpty(
            userId: user.$id,
            languageCode: langCode,
            seedCount: 100,
          );
        } else {
          rethrow;
        }
      }
      final stats = await _learningService.getProgressStats(user.$id);
      print('HomeProvider stats: $stats');
      _knownCount = stats[WordStatus.known] ?? 0;
      _inProgressCount = stats[WordStatus.inProgress] ?? 0;
      _newWordsCount = stats[WordStatus.New] ?? 0;
    } catch (e) {
      // Handle not being logged in
      print('HomeProvider error: $e');
      _knownCount = 0;
      _inProgressCount = 0;
      _newWordsCount = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(refresh);
    super.dispose();
  }
}
