import 'package:flutter/foundation.dart';
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

  HomeProvider(
    this._learningService,
    this._settingsProvider,
    this._appwriteService,
  ) {
    _settingsProvider.addListener(refresh);
    refresh();
  }

  Future<void> refresh() async {
    try {
      final user = await _appwriteService.account.get();
      final stats = await _learningService.getProgressStats(user.$id);
      _knownCount = stats[WordStatus.known] ?? 0;
      _inProgressCount = stats[WordStatus.inProgress] ?? 0;
      _newWordsCount = stats[WordStatus.New] ?? 0;
    } catch (e) {
      // Handle not being logged in
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