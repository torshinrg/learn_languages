// lib/presentation/providers/custom_words_provider.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/custom_word.dart';
import '../../domain/repositories/i_custom_word_repository.dart';
import '../../domain/repositories/i_srs_repository.dart';

class CustomWordsProvider extends ChangeNotifier {
  final ICustomWordRepository _repo;

  // Initialize once, here inline—remove any constructor initializer for _srs
  final ISRSRepository _srs = GetIt.instance<ISRSRepository>();

  final _uuid = Uuid();
  List<CustomWord> _words = [];
  List<CustomWord> get words => List.unmodifiable(_words);

  CustomWordsProvider(this._repo) {
    _load();
  }

  Future<void> _load() async {
    _words = await _repo.fetchAll();
    notifyListeners();
  }

  Future<void> add(String text) async {
    final word = CustomWord(id: _uuid.v4(), text: text.trim());
    await _repo.add(word);

    // Schedule its very first review
    await _srs.scheduleNext(word.id, true);

    _words.add(word);
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    _words.removeWhere((w) => w.id == id);
    notifyListeners();
  }
}
