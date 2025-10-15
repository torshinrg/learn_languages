import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/local/reading_progress_store.dart';
import '../../data/remote/appwrite_service.dart';
import '../../domain/entities/material_sentence.dart';
import '../../domain/entities/reading_material.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/user_word_status.dart';
import '../../domain/entities/word.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/i_material_sentence_repository.dart';
import '../../domain/repositories/i_reading_material_repository.dart';
import '../../domain/repositories/i_user_word_status_repository.dart';
import '../../domain/repositories/i_word_repository.dart';
import '../../domain/repositories/i_task_repository.dart';
import '../../domain/repositories/i_task_translation_repository.dart';
import '../../domain/repositories/i_language_repository.dart';
import 'settings_provider.dart';

class ReaderProvider extends ChangeNotifier {
  ReaderProvider({
    required this.materialId,
    required IReadingMaterialRepository materialRepository,
    required IMaterialSentenceRepository materialSentenceRepository,
    required IWordRepository wordRepository,
    required IUserWordStatusRepository userWordStatusRepository,
    required ReadingProgressStore progressStore,
    required AppwriteService appwriteService,
    required ITaskRepository taskRepository,
    required ITaskTranslationRepository taskTranslationRepository,
    required ILanguageRepository languageRepository,
    required SettingsProvider settingsProvider,
  }) : _materialRepository = materialRepository,
       _materialSentenceRepository = materialSentenceRepository,
       _wordRepository = wordRepository,
       _userWordStatusRepository = userWordStatusRepository,
       _progressStore = progressStore,
       _appwriteService = appwriteService,
       _taskRepository = taskRepository,
       _taskTranslationRepository = taskTranslationRepository,
       _languageRepository = languageRepository,
       _settingsProvider = settingsProvider {
    _audioPlayer.playerStateStream.listen(_handlePlayerState);
  }

  final String materialId;
  final IReadingMaterialRepository _materialRepository;
  final IMaterialSentenceRepository _materialSentenceRepository;
  final IWordRepository _wordRepository;
  final IUserWordStatusRepository _userWordStatusRepository;
  final ReadingProgressStore _progressStore;
  final AppwriteService _appwriteService;
  final ITaskRepository _taskRepository;
  final ITaskTranslationRepository _taskTranslationRepository;
  final ILanguageRepository _languageRepository;
  final SettingsProvider _settingsProvider;

  final AudioPlayer _audioPlayer = AudioPlayer();

  ReadingMaterial? _material;
  bool _initialized = false;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  String? _errorMessage;
  int _currentIndex = 0;
  int? _resumeOrder;
  String? _userId;
  bool _isResuming = false;

  final List<MaterialSentence> _sentences = [];
  final Map<int, SentenceViewData> _viewCache = {};
  final Map<String, Word?> _wordCache = {};
  final Map<String, UserWordStatus?> _statusCache = {};
  final Map<String, List<Task>> _tasksCache = {};
  final Set<String> _prefetchingKeys = {};
  final Map<String, String> _taskPromptCache = {};
  bool _hasLoadedSentenceTasks = false;
  bool _isLoadingSentenceTasks = false;
  List<Task> _sentenceTasks = [];
  final Map<String, String> _languageCodeToId = {};
  final Map<String, String> _languageIdToCode = {};
  bool _languagesLoaded = false;
  String? _currentAudioSentenceId;

  static const List<int> _pageSizes = [1, 5, 10];
  int _pageSizeIndex = 0;
  int _totalSentences = 0;
  bool _autoplayPending = false;

  bool get isLoading => _isLoading;
  bool get isInitialized => _initialized;
  bool get isAudioPlaying => _audioPlayer.playing;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  ReadingMaterial? get material => _material;
  int get sentenceCount => _sentences.length;
  int get currentIndex => _currentIndex;
  MaterialSentence? get currentSentence =>
      _sentences.isEmpty
          ? null
          : _sentences[min(_currentIndex, _sentences.length - 1)];
  AudioPlayer get audioPlayer => _audioPlayer;
  int get totalSentences =>
      _totalSentences > 0 ? _totalSentences : _sentences.length;
  bool get autoplayPending => _autoplayPending;
  bool get isResuming => _isResuming;

  Future<void> init({ReadingMaterial? material}) async {
    if (_initialized) return;
    _initialized = true;
    _setLoading(true);
    try {
      _material = material ?? await _materialRepository.getById(materialId);
      if (_material == null) {
        _errorMessage = 'material_not_found';
        _setLoading(false);
        return;
      }

      final progress = await _progressStore.loadProgress(materialId);
      _resumeOrder = progress?.lastOrder;
      await _loadInitialSentences();
      _setLoading(false);
    } catch (e) {
      _errorMessage = e.toString();
      _setLoading(false);
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore || !_hasMore) return;
    if (_totalSentences > 0 && _sentences.length >= _totalSentences) {
      _hasMore = false;
      return;
    }
    if (_sentences.isEmpty) return;
    _isFetchingMore = true;
    try {
      final lastOrder = _sentences.last.order;
      final limit = _nextPageSize();
      final page = await _materialSentenceRepository.fetchByMaterial(
        materialId,
        limit: limit,
        startAfterOrder: lastOrder,
      );
      if (page.total > 0) {
        _totalSentences = max(_totalSentences, page.total);
      }
      final nextBatch = page.items;
      if (nextBatch.isEmpty) {
        _hasMore = false;
      } else {
        _appendSentences(nextBatch);
      }
      if (_totalSentences > 0 && _sentences.length >= _totalSentences) {
        _hasMore = false;
      }
    } finally {
      _isFetchingMore = false;
    }
    _maybePrefetch();
  }

  Future<SentenceViewData?> ensureCurrentView() async {
    final sentence = currentSentence;
    if (sentence == null) return null;
    final index = _currentIndex;
    if (_viewCache.containsKey(index)) {
      return _viewCache[index];
    }
    final view = await _buildView(sentence, index);
    _viewCache[index] = view;
    return view;
  }

  Future<SentenceViewData?> ensureViewForIndex(int index) async {
    if (index < 0 || index >= _sentences.length) return null;
    if (_viewCache.containsKey(index)) {
      return _viewCache[index];
    }
    final view = await _buildView(_sentences[index], index);
    _viewCache[index] = view;
    return view;
  }

  void nextSentence({bool autoPlay = false}) {
    if (_currentIndex >= _sentences.length - 1) {
      return;
    }
    _currentIndex += 1;
    _persistProgress();
    _currentAudioSentenceId = null;
    notifyListeners();
    if (autoPlay) {
      _requestAutoplay();
    }
    _maybePrefetch();
  }

  void previousSentence({bool autoPlay = false}) {
    if (_currentIndex == 0) return;
    _currentIndex -= 1;
    _persistProgress();
    _currentAudioSentenceId = null;
    notifyListeners();
    if (autoPlay) {
      _requestAutoplay();
    }
    _maybePrefetch();
  }

  Future<void> jumpToSentence(int index, {bool autoPlay = false}) async {
    if (index < 0 || index >= _sentences.length) return;
    _currentIndex = index;
    _persistProgress();
    _currentAudioSentenceId = null;
    notifyListeners();
    if (autoPlay) {
      _requestAutoplay();
    }
    _maybePrefetch();
  }

  Future<void> playCurrentSentence({bool restart = false}) async {
    _autoplayPending = false;
    final sentence = currentSentence?.sentence;
    if (sentence == null) return;
    final url = _resolveAudioUrl(sentence);
    if (url == null) return;
    try {
      final sameSentence = _currentAudioSentenceId == sentence.id;
      final shouldReload =
          restart || !sameSentence || _audioPlayer.audioSource == null;
      if (shouldReload) {
        _currentAudioSentenceId = sentence.id;
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(url);
      }
      await _audioPlayer.play();
    } catch (_) {
      // swallow audio errors for now
    }
  }

  Future<void> pause() async {
    await _audioPlayer.pause();
    _autoplayPending = false;
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentAudioSentenceId = null;
  }

  Future<WordLookupResult> lookupWord(SentenceTokenData token) async {
    final languageId = token.languageId;
    if (languageId.isEmpty) {
      return WordLookupResult(token: token);
    }
    final key = '${languageId}_${token.normalized}';
    Word? word = token.word ?? _wordCache[key];
    word ??= await _wordRepository.findByLemma(token.normalized, languageId);
    word ??= await _wordRepository.findBySurface(token.normalized, languageId);
    _wordCache[key] = word;

    UserWordStatus? status;
    if (word != null) {
      status = await _lookupStatus(word.id);
    }

    return WordLookupResult(token: token, word: word, status: status);
  }

  Future<void> updateWordStatus(Word word, WordStatus status) async {
    final userId = await _ensureUserId();
    if (userId == null) return;

    final existing = _statusCache[word.id];
    final updated = UserWordStatus(
      id: existing?.id ?? '',
      userId: userId,
      wordId: word.id,
      status: status,
    );

    if (existing == null) {
      await _userWordStatusRepository.create(updated);
    } else {
      await _userWordStatusRepository.update(updated);
    }
    _statusCache[word.id] = updated;

    // Update cached tokens so highlights reflect the new status immediately.
    for (final entry in _viewCache.entries.toList()) {
      final tokens = entry.value.tokens;
      var changed = false;
      final updatedTokens = <SentenceTokenData>[];
      for (final token in tokens) {
        if (token.word?.id == word.id ||
            token.normalized == word.text.toLowerCase()) {
          updatedTokens.add(token.copyWith(word: word, status: status));
          changed = true;
        } else {
          updatedTokens.add(token);
        }
      }
      if (changed) {
        _viewCache[entry.key] = entry.value.copyWith(tokens: updatedTokens);
      }
    }
    notifyListeners();
  }

  double progressPercent() {
    final total = totalSentences;
    if (total == 0) return 0;
    final position = min(_currentIndex, total - 1);
    return (position + 1) / total;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSentences() async {
    _sentences.clear();
    _viewCache.clear();
    _hasMore = true;
    _pageSizeIndex = 0;
    _totalSentences = 0;
    _tasksCache.clear();
    _wordCache.clear();
    _prefetchingKeys.clear();
    _taskPromptCache.clear();
    _sentenceTasks = [];
    _hasLoadedSentenceTasks = false;
    _currentAudioSentenceId = null;
    _totalSentences = 0;

    final firstLimit = _pageSizes.isNotEmpty ? _pageSizes.first : 1;
    final firstPage = await _materialSentenceRepository.fetchByMaterial(
      materialId,
      limit: firstLimit,
    );
    if (firstPage.total > 0) {
      _totalSentences = max(_totalSentences, firstPage.total);
    }
    final firstItems = firstPage.items;
    if (firstItems.isEmpty) {
      _hasMore = false;
    }
    _appendSentences(firstItems);
    if (_totalSentences > 0 && _sentences.length >= _totalSentences) {
      _hasMore = false;
    }

    if (_pageSizes.length > 1 && _sentences.isNotEmpty) {
      _pageSizeIndex = 1;
      final additionalPage = await _materialSentenceRepository.fetchByMaterial(
        materialId,
        limit: _pageSizes[1],
        startAfterOrder: _sentences.last.order,
      );
      if (additionalPage.total > 0) {
        _totalSentences = max(_totalSentences, additionalPage.total);
      }
      _appendSentences(additionalPage.items);
      if (_pageSizes.length > 2) {
        _pageSizeIndex = 2;
      }
      if (_totalSentences > 0 && _sentences.length >= _totalSentences) {
        _hasMore = false;
      }
    }

    if (_resumeOrder != null && _resumeOrder! > 0) {
      _setResuming(true);
      try {
        await _seekToOrder(_resumeOrder!);
      } finally {
        _setResuming(false);
      }
    } else {
      _persistProgress();
      _requestAutoplay();
    }
    _maybePrefetch();
  }

  Future<void> _seekToOrder(int order) async {
    var targetIndex = _sentences.indexWhere((s) => s.order >= order);
    while (targetIndex == -1 && _hasMore) {
      await loadMore();
      targetIndex = _sentences.indexWhere((s) => s.order >= order);
    }
    if (targetIndex == -1) {
      _currentIndex = _sentences.length - 1;
    } else {
      _currentIndex = targetIndex;
    }
    _persistProgress();
    _currentAudioSentenceId = null;
    notifyListeners();
    _requestAutoplay();
    _maybePrefetch();
  }

  Future<SentenceViewData> _buildView(
    MaterialSentence materialSentence,
    int viewIndex,
  ) async {
    final sentence = materialSentence.sentence;
    if (sentence == null) {
      return SentenceViewData(
        sentence: materialSentence,
        tokens: const [],
        tasks: const [],
      );
    }

    final tokens = await _buildTokens(sentence, viewIndex);
    final tasks = await _tasksForSentence(materialSentence);
    return SentenceViewData(
      sentence: materialSentence,
      tokens: tokens,
      tasks: tasks,
    );
  }

  Future<List<SentenceTokenData>> _buildTokens(
    Sentence sentence,
    int viewIndex,
  ) async {
    final languageId = sentence.languageId;
    final languageCode = await _languageCodeForId(languageId) ?? '';
    final tokens =
        sentence.tokenLemmas.isNotEmpty
            ? sentence.tokenLemmas
            : (sentence.tokenSurfaces.isNotEmpty
                ? sentence.tokenSurfaces
                : sentence.content.split(RegExp(r'\s+')));
    final surfaces =
        sentence.tokenSurfaces.isNotEmpty ? sentence.tokenSurfaces : tokens;

    final List<SentenceTokenData> results = [];
    final Set<String> toPrefetch = {};
    for (var i = 0; i < tokens.length; i++) {
      final text = i < surfaces.length ? surfaces[i] : tokens[i];
      final lemma =
          i < sentence.tokenLemmas.length ? sentence.tokenLemmas[i] : null;
      final normalized = (lemma ?? text).toLowerCase();
      Word? word;
      WordStatus? status;
      final cacheKey = '${languageId}_$normalized';
      if (_wordCache.containsKey(cacheKey)) {
        word = _wordCache[cacheKey];
      } else {
        toPrefetch.add(normalized);
      }

      if (word != null) {
        final userStatus = await _lookupStatus(word.id);
        status = userStatus?.status;
      }

      results.add(
        SentenceTokenData(
          text: text,
          lemma: lemma,
          languageId: languageId,
          languageCode: languageCode,
          normalized: normalized,
          word: word,
          status: status,
        ),
      );
    }
    _prefetchTokenDetails(languageId, toPrefetch, viewIndex);
    return results;
  }

  void _prefetchTokenDetails(
    String languageId,
    Set<String> normalizedValues,
    int viewIndex,
  ) {
    if (normalizedValues.isEmpty) return;
    final toFetch = <String>[];
    for (final normalized in normalizedValues) {
      if (normalized.isEmpty) continue;
      final key = '${languageId}_$normalized';
      if (_wordCache.containsKey(key)) continue;
      if (_prefetchingKeys.contains(key)) continue;
      _prefetchingKeys.add(key);
      toFetch.add(normalized);
    }
    if (toFetch.isEmpty) return;

    unawaited(() async {
      try {
        for (final normalized in toFetch) {
          final key = '${languageId}_$normalized';
          Word? word = await _wordRepository.findByLemma(
            normalized,
            languageId,
          );
          word ??= await _wordRepository.findBySurface(normalized, languageId);
          _wordCache[key] = word;
          _prefetchingKeys.remove(key);
          if (word != null) {
            await _lookupStatus(word.id);
          }
        }

        final view = _viewCache[viewIndex];
        if (view == null) return;
        final updatedTokens =
            view.tokens.map((token) {
              final key = '${token.languageId}_${token.normalized}';
              final word = _wordCache[key];
              WordStatus? status;
              if (word != null) {
                status = _statusCache[word.id]?.status;
              }
              if (word == token.word && status == token.status) {
                return token;
              }
              return token.copyWith(word: word, status: status);
            }).toList();
        _viewCache[viewIndex] = view.copyWith(tokens: updatedTokens);
        notifyListeners();
      } catch (_) {
        for (final normalized in toFetch) {
          _prefetchingKeys.remove('${languageId}_$normalized');
        }
      }
    }());
  }

  Future<List<Task>> _tasksForSentence(
    MaterialSentence materialSentence,
  ) async {
    final sentenceId = materialSentence.sentenceId;
    if (_tasksCache.containsKey(sentenceId)) {
      return _tasksCache[sentenceId]!;
    }

    final rawLanguage =
        _settingsProvider.nativeLanguageCode ??
        _settingsProvider.locale.languageCode;
    final languageCode = rawLanguage.toLowerCase().split(RegExp(r'[-_]')).first;
    if (languageCode.isEmpty) {
      _tasksCache[sentenceId] = const [];
      return const [];
    }
    final nativeLanguageId = await _languageIdForCode(languageCode);
    if (nativeLanguageId == null || nativeLanguageId.isEmpty) {
      _tasksCache[sentenceId] = const [];
      return const [];
    }
    final task = await _sentenceTaskForLanguage(
      sentenceId,
      nativeLanguageId,
      languageCode,
    );
    final List<Task> result = task != null ? <Task>[task] : <Task>[];
    _tasksCache[sentenceId] = result;
    return result;
  }

  Future<void> _ensureSentenceTasks() async {
    if (_hasLoadedSentenceTasks) return;
    if (_isLoadingSentenceTasks) {
      while (_isLoadingSentenceTasks) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    _isLoadingSentenceTasks = true;
    try {
      _sentenceTasks = await _taskRepository.fetchAllSentenceTasks();
    } catch (_) {
      _sentenceTasks = [];
    } finally {
      _isLoadingSentenceTasks = false;
      _hasLoadedSentenceTasks = true;
    }
  }

  Future<Task?> _sentenceTaskForLanguage(
    String sentenceId,
    String languageId,
    String languageCode,
  ) async {
    await _ensureSentenceTasks();
    if (_sentenceTasks.isEmpty) return null;
    final candidates =
        _sentenceTasks.where((task) => task.languageId == languageId).toList();
    if (candidates.isEmpty) return null;

    final seed = sentenceId.hashCode ^ languageId.hashCode;
    final index = seed.abs() % candidates.length;
    final baseTask = candidates[index];
    final prompt = await _promptForTask(baseTask, languageCode);
    return baseTask.copyWith(promptTemplate: prompt);
  }

  Future<String> _promptForTask(Task task, String languageCode) async {
    if (languageCode.isEmpty) {
      return task.promptTemplate;
    }
    final cacheKey = '${task.id}::$languageCode';
    final cached = _taskPromptCache[cacheKey];
    if (cached != null) {
      return cached;
    }
    try {
      final translation = await _taskTranslationRepository.fetch(
        task.id,
        languageCode,
      );
      final translated = translation?.promptTemplate.trim();
      final resolved =
          translated != null && translated.isNotEmpty
              ? translated
              : task.promptTemplate;
      _taskPromptCache[cacheKey] = resolved;
      return resolved;
    } catch (_) {
      _taskPromptCache[cacheKey] = task.promptTemplate;
      return task.promptTemplate;
    }
  }

  Future<String?> _languageIdForCode(String code) async {
    if (code.isEmpty) return null;
    await _ensureLanguages();
    return _languageCodeToId[code.toLowerCase()];
  }

  Future<String?> _languageCodeForId(String id) async {
    if (id.isEmpty) return null;
    await _ensureLanguages();
    return _languageIdToCode[id];
  }

  Future<void> _ensureLanguages() async {
    if (_languagesLoaded) return;
    try {
      final languages = await _languageRepository.fetchAll();
      for (final language in languages) {
        _languageCodeToId[language.code.toLowerCase()] = language.id;
        _languageIdToCode[language.id] = language.code;
      }
    } catch (_) {
      // ignore failures; we'll fall back to empty map
    }
    _languagesLoaded = true;
  }

  void _appendSentences(List<MaterialSentence> batch) {
    if (batch.isEmpty) return;
    final existingOrders = _sentences.map((e) => e.order).toSet();
    var added = false;
    for (final sentence in batch) {
      if (existingOrders.contains(sentence.order)) continue;
      _sentences.add(sentence);
      added = true;
      existingOrders.add(sentence.order);
    }
    if (added) {
      _sentences.sort((a, b) => a.order.compareTo(b.order));
      notifyListeners();
    }
  }

  void _setResuming(bool value) {
    if (_isResuming == value) return;
    _isResuming = value;
    notifyListeners();
  }

  int _nextPageSize() {
    if (_pageSizes.isEmpty) {
      return 10;
    }
    final index = _pageSizeIndex.clamp(0, _pageSizes.length - 1);
    final size = _pageSizes[index];
    if (_pageSizeIndex < _pageSizes.length - 1) {
      _pageSizeIndex += 1;
    }
    return size;
  }

  void _maybePrefetch() {
    if (_isFetchingMore || !_hasMore) return;
    if (_totalSentences > 0 && _sentences.length >= _totalSentences) {
      _hasMore = false;
      return;
    }
    if ((_sentences.length - _currentIndex) <= 10) {
      loadMore();
    }
  }

  Future<UserWordStatus?> _lookupStatus(String wordId) async {
    if (_statusCache.containsKey(wordId)) {
      return _statusCache[wordId];
    }
    final userId = await _ensureUserId();
    if (userId == null) return null;
    try {
      final status = await _userWordStatusRepository.fetch(userId, wordId);
      _statusCache[wordId] = status;
      return status;
    } catch (_) {
      _statusCache[wordId] = null;
      return null;
    }
  }

  Future<String?> _ensureUserId() async {
    if (_userId != null) return _userId;
    try {
      final user = await _appwriteService.account.get();
      _userId = user.$id;
    } catch (_) {
      _userId = null;
    }
    return _userId;
  }

  void _persistProgress() {
    final sentence = currentSentence;
    if (sentence == null) return;
    _progressStore.saveProgress(materialId, sentence.order);
  }

  String? _resolveAudioUrl(Sentence sentence) {
    final raw = sentence.audioId ?? sentence.audioUrl;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (sentence.sentenceType == 'book') {
      final projectId = dotenv.env['APPWRITE_PROJECT_ID'] ?? 'demo';
      return 'https://nyc.cloud.appwrite.io/v1/storage/buckets/book_audios/files/$raw/view?project=$projectId&mode=admin';
    }
    final base =
        dotenv.env['TATOEBA_DOWNLOAD_BASE'] ??
        'https://tatoeba.org/audio/download';
    return '$base/$raw';
  }

  void _handlePlayerState(PlayerState state) {
    // No automatic navigation after completion for reading flow.
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _requestAutoplay() {
    _autoplayPending = true;
  }
}

class SentenceTokenData {
  SentenceTokenData({
    required this.text,
    required this.normalized,
    required this.languageId,
    this.languageCode,
    this.lemma,
    this.word,
    this.status,
  });

  final String text;
  final String normalized;
  final String languageId;
  final String? languageCode;
  final String? lemma;
  final Word? word;
  final WordStatus? status;

  SentenceTokenData copyWith({
    Word? word,
    WordStatus? status,
    String? languageCode,
  }) {
    return SentenceTokenData(
      text: text,
      normalized: normalized,
      languageId: languageId,
      languageCode: languageCode ?? this.languageCode,
      lemma: lemma,
      word: word ?? this.word,
      status: status ?? this.status,
    );
  }
}

class SentenceViewData {
  const SentenceViewData({
    required this.sentence,
    required this.tokens,
    required this.tasks,
  });

  final MaterialSentence sentence;
  final List<SentenceTokenData> tokens;
  final List<Task> tasks;

  SentenceViewData copyWith({
    List<SentenceTokenData>? tokens,
    List<Task>? tasks,
  }) {
    return SentenceViewData(
      sentence: sentence,
      tokens: tokens ?? this.tokens,
      tasks: tasks ?? this.tasks,
    );
  }
}

class WordLookupResult {
  WordLookupResult({required this.token, this.word, this.status});

  final SentenceTokenData token;
  final Word? word;
  final UserWordStatus? status;
}
