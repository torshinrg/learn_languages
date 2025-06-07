// lib/presentation/providers/custom_words_provider.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/custom_word.dart';
import '../../domain/repositories/i_custom_word_repository.dart';

class CustomWordsProvider extends ChangeNotifier {
  final ICustomWordRepository _repo;
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

  Future<void> add(String text, String languageCode) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1) See if this text already exists among custom words
    CustomWord? existing;
    for (final w in _words) {
      if (w.text == trimmed && w.languageCode == languageCode) {
        existing = w;
        break;
      }
    }

    // 2) Build the new-or-updated Word
    final id = existing?.id ?? _uuid.v4();
    final word = CustomWord(
      id: id,
      text: trimmed,
      languageCode: languageCode,
    );

    // 3) Insert or replace in DB
    await _repo.add(word);

    // 4) Reload our in-memory list and notify
    await _load();
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    await _load();
  }
}
