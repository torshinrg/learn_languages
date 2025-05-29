// lib/presentation/providers/custom_words_provider.dart

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/word.dart';
import '../../domain/repositories/i_word_repository.dart';
import '../../domain/repositories/i_srs_repository.dart';

class CustomWordsProvider extends ChangeNotifier {
  final IWordRepository _wordRepo;
  final ISRSRepository _srs;
  final _uuid = Uuid();

  List<Word> _words = [];
  List<Word> get words => List.unmodifiable(_words);

  CustomWordsProvider(this._wordRepo, this._srs) {
    _load();
  }

  Future<void> _load() async {
    // load all words and keep only custom ones
    final all = await _wordRepo.fetchAll();
    _words = all.where((w) => w.type == WordType.custom).toList();
    notifyListeners();
  }

  Future<void> add(
      String text, {
        String? translation,
        String? sentence,
      }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // 1) See if this text already exists among custom words
    Word? existing;
    for (final w in _words) {
      if (w.text == trimmed) {
        existing = w;
        break;
      }
    }

    // 2) Build the new-or-updated Word
    final id = existing?.id ?? _uuid.v4();
    final word = Word(
      id: id,
      text: trimmed,
      translation: translation,
      sentence: sentence,
      type: WordType.custom,
    );

    // 3) Insert or replace in DB
    await _wordRepo.addOrUpdate(word);



    // 5) Reload our in-memory list and notify
    await _load();
  }

  Future<void> remove(String id) async {
    // On delete, revert it back to a normal word
    final all = await _wordRepo.fetchAll();
    final original = all.firstWhere((w) => w.id == id);
    final updated = Word(
      id: original.id,
      text: original.text,
      translation: original.translation,
      sentence: original.sentence,
      type: WordType.normal,
    );
    await _wordRepo.addOrUpdate(updated);
    await _load();
  }
}
