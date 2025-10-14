import 'package:flutter/foundation.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/domain/entities/word.dart';
import 'package:learn_languages/services/learning_service.dart';

import '../../data/remote/appwrite_service.dart';

class VocabularyProvider extends ChangeNotifier {
  final LearningService _learningService;
  final AppwriteService _appwriteService;

  List<Word> _learningNow = [];
  List<Word> get learningNow => _learningNow;

  List<Word> _pending = [];
  List<Word> get pending => _pending;

  List<Word> _mastered = [];
  List<Word> get mastered => _mastered;

  List<Word> get learned => _mastered;

  VocabularyProvider(this._learningService, this._appwriteService) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final user = await _appwriteService.account.get();
      _learningNow =
          await _learningService.getWordsByStatus(user.$id, WordStatus.inProgress);
      _pending = await _learningService.getWordsByStatus(user.$id, WordStatus.New);
      _mastered =
          await _learningService.getWordsByStatus(user.$id, WordStatus.known);
      print('VocabularyProvider learningNow: ${_learningNow.length}');
      print('VocabularyProvider pending: ${_pending.length}');
      print('VocabularyProvider mastered: ${_mastered.length}');
    } catch (e) {
      print('VocabularyProvider error: $e');
      _learningNow = [];
      _pending = [];
      _mastered = [];
    }
    notifyListeners();
  }
}
