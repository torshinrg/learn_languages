import 'package:flutter/foundation.dart';
import '../../services/learning_service.dart';
import '../../services/srs_service.dart';
import 'settings_provider.dart';

class HomeProvider extends ChangeNotifier {
  final SRSService _srsService;
  final LearningService _learningService;
  final SettingsProvider _settingsProvider;

  int _dueCount = 0;
  bool _canStudy = false;

  int get dueCount => _dueCount;
  bool get canStudy => _canStudy;

  /// How many *new* words you can still learn today:
  int get availableCount =>
      (_settingsProvider.dailyCount - _settingsProvider.studiedCount).clamp(
        0,
        _settingsProvider.dailyCount,
      );

  HomeProvider(
    this._srsService,
    this._learningService,
    this._settingsProvider,
  ) {
    // Re-compute whenever settings (dailyCount or studiedCount) change:
    _settingsProvider.addListener(_onSettingsChanged);

    // Initial load of due/review state and study availability:
    _refreshAll();

    // Pre-warm the “study” sentences for faster startup:
    _preloadStudySentences();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadDueCount(), _loadCanStudy()]);
  }

  Future<void> _loadDueCount() async {
    final dueWords = await _learningService.getDueWords();
    _dueCount = dueWords.length;
    notifyListeners();
  }

  Future<void> _loadCanStudy() async {
    final daily = _settingsProvider.dailyCount;
    final studied = _settingsProvider.studiedCount;

    if (studied >= daily) {
      _canStudy = false;
      notifyListeners();
      return;
    }

    final batch = await _learningService.getDailyBatch(daily);
    _canStudy = batch.isNotEmpty && studied < daily;
    notifyListeners();
  }

  void _onSettingsChanged() {
    // dailyCount or studiedCount changed
    _refreshAll();
  }

  /// Call after returning from other screens
  Future<void> refresh() => _refreshAll();

  @override
  void dispose() {
    _settingsProvider.removeListener(_onSettingsChanged);
    super.dispose();
  }

  Future<void> _preloadStudySentences() async {
    final count = _settingsProvider.dailyCount;
    final batch = await _learningService.getDailyBatch(count);
    final languageCode = _settingsProvider.learningLanguageCodes.first;

    // Fire‐and‐forget both initial and remaining example fetches:
    for (final w in batch) {
      _learningService.getInitialSentencesForWord(
        w.text,
        languageCode,
        limit: 3,
        translationCode: _settingsProvider.nativeLanguageCode,
      );
      _learningService.getRemainingSentencesForWord(
        w.text,
        [],
        languageCode,
        translationCode: _settingsProvider.nativeLanguageCode,
      );
    }
  }
}
