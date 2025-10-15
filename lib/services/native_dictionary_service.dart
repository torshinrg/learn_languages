import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'translation_service.dart';

class NativeDictionaryEntry {
  NativeDictionaryEntry({
    required this.word,
    required this.lookupTerm,
    required this.targetLang,
    this.pos,
    required this.definitions,
    required this.examples,
    required this.synonyms,
    required this.antonyms,
    required this.sourceUrl,
    this.pronunciations = const [],
    this.etymology,
    this.fallback,
    this.sourceLang,
    this.translation,
  });

  final String word;
  final String lookupTerm;
  final String targetLang;
  final String? pos;
  final List<String> definitions;
  final List<List<String>> examples;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> pronunciations;
  final String? etymology;
  final String? sourceUrl;
  final String? fallback;
  final String? sourceLang;
  final String? translation;

  bool get isFallback => fallback != null;

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'lookupTerm': lookupTerm,
      'targetLang': targetLang,
      'pos': pos,
      'definitions': definitions,
      'examples': examples,
      'synonyms': synonyms,
      'antonyms': antonyms,
      'pronunciations': pronunciations,
      'etymology': etymology,
      'sourceUrl': sourceUrl,
      'fallback': fallback,
      'sourceLang': sourceLang,
      'translation': translation,
    };
  }

  static NativeDictionaryEntry? fromJson(Map<String, dynamic> map) {
    final word = map['word'];
    final lookupTerm = map['lookupTerm'];
    final targetLang = map['targetLang'];
    if (word is! String || lookupTerm is! String || targetLang is! String) {
      return null;
    }
    return NativeDictionaryEntry(
      word: word,
      lookupTerm: lookupTerm,
      targetLang: targetLang,
      pos: map['pos'] as String?,
      definitions: _readStringList(map['definitions']),
      examples: _readExampleList(map['examples']),
      synonyms: _readStringList(map['synonyms']),
      antonyms: _readStringList(map['antonyms']),
      pronunciations: _readStringList(map['pronunciations']),
      etymology: map['etymology'] as String?,
      sourceUrl: map['sourceUrl'] as String?,
      fallback: map['fallback'] as String?,
      sourceLang: map['sourceLang'] as String?,
      translation: map['translation'] as String?,
    );
  }

  static List<String> _readStringList(Object? raw) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((element) => element.trim())
          .where((element) => element.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<List<String>> _readExampleList(Object? raw) {
    if (raw is List) {
      return raw
          .map((group) {
            if (group is List) {
              return group
                  .whereType<String>()
                  .map((element) => element.trim())
                  .where((element) => element.isNotEmpty)
                  .toList();
            }
            if (group is String) {
              final trimmed = group.trim();
              return trimmed.isEmpty ? <String>[] : <String>[trimmed];
            }
            return <String>[];
          })
          .where((group) => group.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

class NativeDictionaryService {
  NativeDictionaryService({
    http.Client? client,
    Duration requestTimeout = const Duration(seconds: 15),
    DateTime Function()? clock,
    TranslationService? translationService,
  }) : _client = client ?? http.Client(),
       _requestTimeout = requestTimeout,
       _clock = clock ?? DateTime.now,
       _translationService = translationService;

  final http.Client _client;
  final Duration _requestTimeout;
  final DateTime Function() _clock;
  final TranslationService? _translationService;

  SharedPreferences? _prefs;

  static const Duration _ttl = Duration(hours: 6);
  static const Duration _debounceWindow = Duration(milliseconds: 250);
  static const String _prefsPrefix = 'native_dictionary_cache:';
  static const String _userAgent = 'FluentanoApp/1.0 (+https://fluentano.app)';
  static const Set<String> _forbiddenContainers = {
    'mw-references-wrap',
    'references',
    'trad-arriba',
    'trad-abajo',
    'caja-responsiva',
  };
  static const Set<String> _forbiddenTags = {'table', 'figure', 'nav'};

  final _MemoryCache<String, _CacheEnvelope> _memoryCache = _MemoryCache(
    capacity: 256,
  );
  final Map<String, Future<NativeDictionaryEntry>> _inflight = {};
  final Map<String, DateTime> _lastNetworkRequest = {};

  Future<void> dispose() async {
    _client.close();
  }

  Future<NativeDictionaryEntry> lookup({
    required String word,
    required String targetLang,
    String? lemma,
    String? sourceLang,
  }) async {
    final normalizedLang = targetLang.trim().toLowerCase();
    final normalizedWord = _normalizeWord(word);
    final normalizedSource =
        sourceLang == null ? '' : sourceLang.trim().toLowerCase();
    final lemmaNormalized = _normalizeWord(lemma ?? '');
    final candidates = <String>[
      if (lemmaNormalized.isNotEmpty) lemmaNormalized,
      if (normalizedWord.isNotEmpty && normalizedWord != lemmaNormalized)
        normalizedWord,
    ];
    if (candidates.isEmpty) {
      return NativeDictionaryEntry(
        word: word,
        lookupTerm: word,
        targetLang: normalizedLang,
        pos: null,
        definitions: const [],
        examples: const [],
        synonyms: const [],
        antonyms: const [],
        sourceUrl: null,
        fallback: null,
        sourceLang: normalizedLang,
      );
    }

    final primaryKey = candidates.first;
    final cacheKey = _cacheKey(
      primaryKey,
      normalizedLang,
      normalizedSource.isEmpty ? null : normalizedSource,
    );
    final now = _clock();

    final memoryEntry = _memoryCache.get(cacheKey);
    if (memoryEntry != null && !_isExpired(memoryEntry, now)) {
      memoryEntry.storedAt = now;
      _memoryCache.set(cacheKey, memoryEntry);
      return memoryEntry.entry;
    } else if (memoryEntry != null) {
      _memoryCache.remove(cacheKey);
    }

    final diskEntry = await _loadFromDisk(cacheKey, now);
    if (diskEntry != null) {
      _memoryCache.set(cacheKey, diskEntry);
      return diskEntry.entry;
    }

    final inFlight = _inflight[cacheKey];
    if (inFlight != null) {
      return inFlight;
    }

    final fetchFuture = _fetchAndCache(
      cacheKey: cacheKey,
      originalWord: word,
      candidates: candidates,
      targetLang: normalizedLang,
      sourceLang: normalizedSource.isEmpty ? null : normalizedSource,
    );
    _inflight[cacheKey] = fetchFuture;
    try {
      return await fetchFuture;
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  Future<NativeDictionaryEntry> _fetchAndCache({
    required String cacheKey,
    required String originalWord,
    required List<String> candidates,
    required String targetLang,
    String? sourceLang,
  }) async {
    NativeDictionaryEntry? fallbackEntry;

    for (final candidate in candidates) {
      final now = _clock();
      final last = _lastNetworkRequest[candidate];
      if (last != null) {
        final diff = now.difference(last);
        if (diff < _debounceWindow) {
          await Future<void>.delayed(_debounceWindow - diff);
        }
      }
      _lastNetworkRequest[candidate] = _clock();

      try {
        final lookup = await _lookupSingle(
          originalWord: originalWord,
          query: candidate,
          targetLang: targetLang,
          sourceLang: sourceLang,
        );
        if (lookup.sourceLang == 'translate') {
          final envelope = _CacheEnvelope(entry: lookup, storedAt: _clock());
          _memoryCache.set(cacheKey, envelope);
          unawaited(_persistToDisk(cacheKey, envelope));
          return lookup;
        }
        if (!lookup.isFallback && lookup.definitions.isNotEmpty) {
          final envelope = _CacheEnvelope(entry: lookup, storedAt: _clock());
          _memoryCache.set(cacheKey, envelope);
          unawaited(_persistToDisk(cacheKey, envelope));
          return lookup;
        }
        final hasMeaning =
            lookup.definitions.isNotEmpty ||
            (lookup.translation != null && lookup.translation!.isNotEmpty);
        if (lookup.isFallback && hasMeaning) {
          fallbackEntry ??= lookup;
        }
        // If definitions are empty, continue to next candidate.
      } on Exception catch (error, stack) {
        debugPrint(
          '[NativeDictionaryService] lookup failed for "$candidate" '
          'lang=$targetLang error=$error stack=$stack',
        );
      }
    }

    final entry =
        fallbackEntry ??
        NativeDictionaryEntry(
          word: originalWord,
          lookupTerm: candidates.first,
          targetLang: targetLang,
          pos: null,
          definitions: const [],
          examples: const [],
          synonyms: const [],
          antonyms: const [],
          sourceUrl: null,
          fallback: null,
          sourceLang: targetLang,
        );
    final envelope = _CacheEnvelope(entry: entry, storedAt: _clock());
    _memoryCache.set(cacheKey, envelope);
    unawaited(_persistToDisk(cacheKey, envelope));
    return entry;
  }

  Future<NativeDictionaryEntry> _lookupSingle({
    required String originalWord,
    required String query,
    required String targetLang,
    String? sourceLang,
  }) async {
    final freedict = await _fetchFreeDictionary(targetLang, query);
    final englishTitle = freedict.englishTitle ?? _toTitle(query);
    final englishUrl = freedict.englishUrl ?? _englishUrlForTitle(englishTitle);
    final englishDefinitions = freedict.englishDefinitions;
    final englishPos = freedict.englishPos;
    final normalizedTarget = targetLang.trim().toLowerCase();
    final normalizedSource =
        sourceLang == null ? '' : sourceLang.trim().toLowerCase();

    debugPrint(
      '[NativeDictionaryService] lookupSingle original="$originalWord" '
      'query="$query" targetLang=$normalizedTarget sourceLang=$normalizedSource '
      'englishTitle="$englishTitle" englishDefs=${englishDefinitions.length}',
    );

    dom.Document? englishDocument = await _loadDocument(url: englishUrl);
    dom.Document? userDocument;
    String? userUrl;

    if (normalizedTarget != 'en') {
      final interwikiCandidates = _interlanguageCandidates(normalizedTarget);
      userUrl = _findInterwikiUrl(
        englishDocument,
        interwikiCandidates,
        englishUrl,
      );
      if (userUrl != null) {
        userDocument = await _loadDocument(url: userUrl);
      } else {
        debugPrint(
          '[NativeDictionaryService] no interwiki link for lang=$normalizedTarget '
          'on english page "$englishTitle"',
        );
      }
    }

    final plans = <_SensePlan>[
      if (userUrl != null)
        _SensePlan(
          label: 'user',
          languageCode: normalizedTarget,
          url: userUrl!,
          preloadedDocument: userDocument,
        ),
      _SensePlan(
        label: 'en',
        languageCode: 'en',
        url: englishUrl,
        preloadedDocument: englishDocument,
      ),
    ];

    for (final plan in plans) {
      final document = await _loadDocument(
        url: plan.url,
        preloaded: plan.preloadedDocument,
      );
      if (document == null) continue;
      final extraction = _extractSenseSlice(
        document: document,
        languageCode: plan.languageCode,
      );
      debugPrint(
        '[NativeDictionaryService] extracted plan=${plan.label} '
        'lang=${plan.languageCode} definitions=${extraction.definitions.length}',
      );
      if (extraction.definitions.isEmpty) continue;
      final fallbackLabel =
          plan.label == 'en' && normalizedTarget != 'en' ? 'english' : null;
      return NativeDictionaryEntry(
        word: originalWord,
        lookupTerm: query,
        targetLang: targetLang,
        pos:
            plan.label == 'en'
                ? (extraction.pos ?? englishPos)
                : extraction.pos,
        definitions: extraction.definitions,
        examples: extraction.examples,
        synonyms: const [],
        antonyms: const [],
        sourceUrl: plan.url,
        pronunciations: const [],
        etymology: null,
        fallback: fallbackLabel,
        sourceLang: plan.label,
      );
    }

    if (englishDefinitions.isNotEmpty) {
      final emptyExamples = List<List<String>>.generate(
        englishDefinitions.length,
        (_) => const [],
      );
      return NativeDictionaryEntry(
        word: originalWord,
        lookupTerm: query,
        targetLang: targetLang,
        pos: englishPos,
        definitions: englishDefinitions,
        examples: emptyExamples,
        synonyms: const [],
        antonyms: const [],
        sourceUrl: englishUrl,
        pronunciations: const [],
        etymology: null,
        fallback: normalizedTarget == 'en' ? null : 'english',
        sourceLang: 'en',
      );
    }

    if (_translationService != null) {
      try {
        final translation = await _translationService!.translate(
          query: originalWord,
          sourceLanguageCode:
              normalizedSource.isNotEmpty ? normalizedSource : 'auto',
          targetLanguageCode: targetLang,
        );
        final translated = translation.text.trim();
        if (translated.isNotEmpty) {
          debugPrint(
            '[NativeDictionaryService] using LibreTranslate fallback '
            'targetLang=$targetLang translation="$translated"',
          );
          return NativeDictionaryEntry(
            word: originalWord,
            lookupTerm: query,
            targetLang: targetLang,
            pos: englishPos,
            definitions: const [],
            examples: const [],
            synonyms: const [],
            antonyms: const [],
            sourceUrl: null,
            pronunciations: const [],
            etymology: null,
            fallback: 'translate',
            sourceLang: 'translate',
            translation: translated,
          );
        }
      } on TranslationException catch (error, stack) {
        debugPrint(
          '[NativeDictionaryService] translation fallback failed '
          'targetLang=$targetLang error=$error stack=$stack',
        );
      } catch (error, stack) {
        debugPrint(
          '[NativeDictionaryService] translation fallback unexpected error '
          'targetLang=$targetLang error=$error stack=$stack',
        );
      }
    } else {
      debugPrint(
        '[NativeDictionaryService] translation fallback unavailable (service null)',
      );
    }

    debugPrint(
      '[NativeDictionaryService] no definitions for "$query" '
      'lang=$normalizedTarget sourceLang=$normalizedSource '
      'englishDefs=${englishDefinitions.length}',
    );

    final emptyExamples = List<List<String>>.generate(
      englishDefinitions.length,
      (_) => const [],
    );

    return NativeDictionaryEntry(
      word: originalWord,
      lookupTerm: query,
      targetLang: targetLang,
      pos: englishPos,
      definitions: englishDefinitions,
      examples: emptyExamples,
      synonyms: const [],
      antonyms: const [],
      sourceUrl: englishUrl,
      pronunciations: const [],
      etymology: null,
      fallback:
          englishDefinitions.isEmpty || normalizedTarget == 'en'
              ? null
              : 'english',
      sourceLang: 'en',
    );
  }

  Future<_FreeDictionaryResult> _fetchFreeDictionary(
    String targetLang,
    String query,
  ) async {
    final encodedWord = Uri.encodeComponent(query);
    final uri = Uri.parse(
      'https://freedictionaryapi.com/api/v1/entries/$targetLang/$encodedWord'
      '?translations=true',
    );
    try {
      final response = await _client
          .get(uri)
          .timeout(
            _requestTimeout,
            onTimeout: () {
              throw TimeoutException('FreeDictionary timeout');
            },
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _FreeDictionaryResult.empty(query);
      }
      final dynamic decoded = jsonDecode(response.body);
      return _FreeDictionaryResult.fromJson(decoded, query);
    } catch (_) {
      return _FreeDictionaryResult.empty(query);
    }
  }

  Future<dom.Document?> _loadDocument({
    required String url,
    dom.Document? preloaded,
  }) async {
    if (preloaded != null) {
      return preloaded;
    }
    final html = await _fetchPageHtml(url);
    if (html == null) return null;
    return html_parser.parse(html);
  }

  Future<String?> _fetchPageHtml(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    try {
      debugPrint('[NativeDictionaryService] fetching page url=$url');
      final response = await _client
          .get(uri, headers: {'Accept': 'text/html', 'User-Agent': _userAgent})
          .timeout(
            _requestTimeout,
            onTimeout: () {
              throw TimeoutException('Wiktionary HTML timeout');
            },
          );
      debugPrint(
        '[NativeDictionaryService] page response url=$url '
        'status=${response.statusCode}',
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body;
      }
    } catch (error) {
      debugPrint(
        '[NativeDictionaryService] page fetch error url=$url error=$error',
      );
    }
    return null;
  }

  _SenseExtractionResult _extractSenseSlice({
    required dom.Document document,
    required String languageCode,
  }) {
    final root = document.querySelector('.mw-parser-output');
    if (root == null) return const _SenseExtractionResult();

    final normalizedLang = languageCode.trim().toLowerCase();
    final languageStart = _findLanguageStart(root, normalizedLang);
    final sliceEnd = _findNextLanguageHeading(languageStart);
    final sliceElements = _collectLanguageSlice(root, languageStart, sliceEnd);
    if (sliceElements.isEmpty) return const _SenseExtractionResult();
    final sliceSet = sliceElements.toSet();

    final dlResult = _extractFromDlBlocks(
      sliceElements: sliceElements,
      sliceSet: sliceSet,
      sliceEnd: sliceEnd,
    );
    if (dlResult.definitions.isNotEmpty) {
      return dlResult;
    }

    final olResult = _extractFromOrderedLists(
      sliceElements: sliceElements,
      sliceSet: sliceSet,
      sliceEnd: sliceEnd,
    );
    if (olResult.definitions.isNotEmpty) {
      return olResult;
    }

    return const _SenseExtractionResult();
  }

  _SenseExtractionResult _extractFromDlBlocks({
    required List<dom.Element> sliceElements,
    required Set<dom.Element> sliceSet,
    required dom.Element? sliceEnd,
  }) {
    String? currentHeading;
    for (final element in sliceElements) {
      if (element == sliceEnd) break;
      if (_isSectionHeading(element)) {
        currentHeading = _headingLabel(element);
        continue;
      }
      if (element.localName != 'dl') continue;
      if (!_looksLikeSenseDl(element)) continue;

      final senses = <_Sense>[];
      dom.Element? cursor = element;
      while (cursor != null &&
          cursor != sliceEnd &&
          sliceSet.contains(cursor) &&
          cursor.localName == 'dl' &&
          _looksLikeSenseDl(cursor)) {
        senses.addAll(_extractSensesFromDl(cursor));
        cursor = cursor.nextElementSibling;
      }
      final deduped = _dedupeSenses(senses);
      if (deduped.isEmpty) {
        return const _SenseExtractionResult();
      }
      return _SenseExtractionResult(
        definitions: deduped.map((sense) => sense.definition).toList(),
        examples: deduped.map((sense) => sense.examples).toList(),
        pos: _normalizePosLabel(currentHeading),
      );
    }
    return const _SenseExtractionResult();
  }

  _SenseExtractionResult _extractFromOrderedLists({
    required List<dom.Element> sliceElements,
    required Set<dom.Element> sliceSet,
    required dom.Element? sliceEnd,
  }) {
    for (final element in sliceElements) {
      if (!_isSectionHeading(element)) continue;
      final headingLabel = _headingLabel(element);
      final senseOl = _findSenseListAfterHeading(
        heading: element,
        sliceEnd: sliceEnd,
        sliceSet: sliceSet,
      );
      if (senseOl == null) continue;
      final senses = _dedupeSenses(_extractSensesFromOl(senseOl));
      if (senses.isEmpty) continue;
      return _SenseExtractionResult(
        definitions: senses.map((sense) => sense.definition).toList(),
        examples: senses.map((sense) => sense.examples).toList(),
        pos: _normalizePosLabel(headingLabel),
      );
    }
    return const _SenseExtractionResult();
  }

  dom.Element? _findSenseListAfterHeading({
    required dom.Element heading,
    required dom.Element? sliceEnd,
    required Set<dom.Element> sliceSet,
  }) {
    dom.Element? node = heading.nextElementSibling;
    while (node != null && node != sliceEnd) {
      if (!sliceSet.contains(node)) break;
      if (_isSectionHeading(node)) break;
      if (_isForbiddenWrapper(node)) {
        node = node.nextElementSibling;
        continue;
      }
      final ol = _extractCandidateOl(node);
      if (ol != null && _isValidSenseOl(ol)) {
        return ol;
      }
      if (_blocksSenseSearch(node)) break;
      node = node.nextElementSibling;
    }
    return null;
  }

  bool _isForbiddenWrapper(dom.Element element) {
    if (_isInsideForbiddenContainer(element)) return true;
    final tag = element.localName;
    if (tag == 'script' || tag == 'style') return true;
    if (tag == 'table' || tag == 'figure' || tag == 'nav') return true;
    final classes = element.classes.map((cls) => cls.toLowerCase()).toSet();
    if (classes.contains('mw-references-wrap') ||
        classes.contains('references')) {
      return true;
    }
    if (element.attributes['role']?.toLowerCase() == 'note') return true;
    return false;
  }

  dom.Element? _extractCandidateOl(dom.Element element) {
    if (element.localName == 'ol') return element;
    if (element.localName == 'div' || element.localName == 'section') {
      for (final child in element.children) {
        if (child.localName == 'ol' && !_isInsideForbiddenContainer(child)) {
          return child;
        }
        final nested = child.querySelector('ol');
        if (nested != null && !_isInsideForbiddenContainer(nested)) {
          return nested;
        }
      }
    }
    return null;
  }

  bool _blocksSenseSearch(dom.Element element) {
    final tag = element.localName;
    if (tag == null) return false;
    if (tag == 'hr') return true;
    if (tag.startsWith('h')) return true;
    if (element.classes.contains('mw-heading')) return true;
    return false;
  }

  List<_Sense> _extractSensesFromDl(dom.Element dl) {
    final senses = <_Sense>[];
    final seen = <String>{};
    for (final child in dl.children) {
      if (child.localName != 'dt') continue;
      final dt = child;
      if (!_isNumericLabel(dt.text)) continue;
      final dd = _nextDefinitionElement(dt);
      if (dd == null) continue;
      if (_isInsideForbiddenContainer(dd)) continue;
      final sense = _parseSenseNode(dd);
      if (sense == null) continue;
      if (seen.add(sense.definition)) {
        senses.add(sense);
      }
    }
    return senses;
  }

  List<_Sense> _extractSensesFromOl(dom.Element ol) {
    final senses = <_Sense>[];
    final seen = <String>{};
    for (final child in ol.children) {
      if (child.localName != 'li') continue;
      final li = child;
      if (_isInsideForbiddenContainer(li)) continue;
      final sense = _parseSenseNode(li);
      if (sense == null) continue;
      if (seen.add(sense.definition)) {
        senses.add(sense);
      }
    }
    return senses;
  }

  _Sense? _parseSenseNode(dom.Element node) {
    final clone = node.clone(true) as dom.Element;
    final examples = _captureExamples(clone);
    _removeNodesBySelector(
      clone,
      'sup.mw-ref.reference, [typeof*="mw:Extension/ref"], .mw-editsection, '
      '.mw-references-wrap, .references, [role="note"], '
      '.trad-arriba, .trad-abajo, .caja-responsiva, '
      '.mw-collapsible, .flex.wikitable',
    );
    _removeNodesBySelector(clone, 'style, script, table, figure, nav');
    _removeElementsByClassSubstring(clone, 'example');
    _removeImmediateLists(clone);
    final text = _cleanText(clone.text);
    if (text.length < 2 || text.length > 350) return null;

    final cleanedExamples =
        examples
            .map(_cleanText)
            .map(_stripExampleLabel)
            .map((sample) => sample.trim())
            .where((sample) => sample.length >= 2 && sample.length <= 200)
            .toList();

    return _Sense(definition: text, examples: cleanedExamples);
  }

  List<String> _captureExamples(dom.Element root) {
    final results = <String>[];
    final directLists =
        root.children
            .whereType<dom.Element>()
            .where(
              (element) =>
                  element.localName == 'ul' || element.localName == 'ol',
            )
            .toList();
    for (final list in directLists) {
      final extracted = _extractExamplesFromList(list);
      if (extracted.isNotEmpty) {
        results.addAll(extracted);
      }
      list.remove();
    }
    final exampleNodes = root.querySelectorAll('[class*=\"example\"]').toList();
    for (final node in exampleNodes) {
      final text = _cleanText(node.text);
      if (_looksLikeExampleText(text)) {
        results.add(text);
      }
      node.remove();
    }
    return results;
  }

  List<String> _extractExamplesFromList(dom.Element list) {
    final examples = <String>[];
    for (final child in list.children) {
      if (child.localName != 'li') continue;
      final text = _cleanText(child.text);
      if (_looksLikeExampleText(text)) {
        examples.add(text);
      }
    }
    return examples;
  }

  bool _looksLikeExampleText(String text) {
    final lower = text.toLowerCase();
    const keywords = ['ejemplo', 'ejemplos', 'example', 'examples', 'exemple'];
    for (final keyword in keywords) {
      if (lower.startsWith('$keyword:') ||
          lower.startsWith('$keyword ') ||
          lower.startsWith('$keyword.')) {
        return true;
      }
    }
    return false;
  }

  String _stripExampleLabel(String text) {
    final lower = text.toLowerCase();
    const keywords = ['ejemplo', 'ejemplos', 'example', 'examples', 'exemple'];
    for (final keyword in keywords) {
      if (lower.startsWith(keyword)) {
        var remainder = text.substring(keyword.length).trimLeft();
        if (remainder.startsWith(':')) {
          remainder = remainder.substring(1).trimLeft();
        }
        return remainder;
      }
    }
    final colon = text.indexOf(':');
    if (colon > 0 && colon < 20) {
      return text.substring(colon + 1).trimLeft();
    }
    return text.trim();
  }

  bool _isValidSenseOl(dom.Element ol) {
    if (_isInsideForbiddenContainer(ol)) return false;
    dom.Node? current = ol.parent;
    while (current != null) {
      if (current is dom.Element) {
        final lowerClasses =
            current.classes.map((cls) => cls.toLowerCase()).toSet();
        if (lowerClasses.contains('mw-references-wrap') ||
            lowerClasses.contains('references')) {
          return false;
        }
        final role = current.attributes['role']?.toLowerCase();
        if (role == 'note') return false;
      }
      current = current.parent;
    }
    final items =
        ol.children
            .whereType<dom.Element>()
            .where((el) => el.localName == 'li')
            .toList();
    if (items.isEmpty) return false;
    var citeCount = 0;
    for (final item in items) {
      final citeLinks =
          item.querySelectorAll('a[href^=\"#cite_note\"]').isNotEmpty;
      if (citeLinks) citeCount++;
    }
    if (citeCount / items.length > 0.6) return false;
    return true;
  }

  List<_Sense> _dedupeSenses(List<_Sense> senses) {
    final seen = <String>{};
    final result = <_Sense>[];
    for (final sense in senses) {
      if (seen.add(sense.definition)) {
        result.add(
          _Sense(definition: sense.definition, examples: sense.examples),
        );
      }
    }
    return result;
  }

  bool _isSectionHeading(dom.Element element) {
    if (element.classes.contains('mw-heading')) return true;
    final name = element.localName ?? '';
    if (name.length == 2 && name.startsWith('h')) {
      final level = int.tryParse(name.substring(1));
      if (level != null && level >= 3 && level <= 6) {
        return true;
      }
    }
    return false;
  }

  String? _headingLabel(dom.Element heading) {
    final text = _cleanText(heading.text);
    if (text.isEmpty) return null;
    return text;
  }

  String? _normalizePosLabel(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 64) return null;
    return trimmed;
  }

  List<String> _interlanguageCandidates(String languageCode) {
    final normalized = languageCode.trim().toLowerCase();
    final candidates = <String>{};
    if (normalized.isNotEmpty) {
      candidates.add(normalized);
      if (normalized.contains('-')) {
        final primary = normalized.split('-').first;
        if (primary.isNotEmpty) {
          candidates.add(primary);
        }
      }
      candidates.add(normalized.replaceAll('_', '-'));
    }
    return candidates.toList();
  }

  String? _findInterwikiUrl(
    dom.Document? document,
    Iterable<String> langCodes,
    String baseUrl,
  ) {
    if (document == null) return null;
    final candidates =
        langCodes
            .map((code) => code.toLowerCase())
            .where((code) => code.isNotEmpty)
            .toSet();
    if (candidates.isEmpty) return null;
    final base = Uri.tryParse(baseUrl);
    final anchors = document.querySelectorAll(
      '#p-lang-btn .vector-menu-content-list a[hreflang]',
    );
    for (final anchor in anchors) {
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) continue;
      final hrefLang = anchor.attributes['hreflang']?.toLowerCase();
      final anchorClasses =
          anchor.classes.map((value) => value.toLowerCase()).toSet();
      final parent = anchor.parent;
      final parentClasses =
          parent is dom.Element
              ? parent.classes.map((value) => value.toLowerCase()).toSet()
              : const <String>{};
      final matchesLang =
          (hrefLang != null && _languageCodeMatches(hrefLang, candidates)) ||
          anchorClasses.any(
            (cls) =>
                cls.startsWith('interwiki-') &&
                _languageCodeMatches(
                  cls.substring('interwiki-'.length),
                  candidates,
                ),
          ) ||
          parentClasses.any(
            (cls) =>
                cls.startsWith('interwiki-') &&
                _languageCodeMatches(
                  cls.substring('interwiki-'.length),
                  candidates,
                ),
          );
      if (!matchesLang) continue;
      if (base != null) {
        return base.resolve(href).toString();
      }
      if (href.startsWith('//')) {
        return 'https:$href';
      }
      if (href.startsWith('/')) {
        return 'https://en.wiktionary.org$href';
      }
      return href;
    }
    return null;
  }

  bool _languageCodeMatches(String value, Set<String> candidates) {
    final lower = value.toLowerCase();
    if (candidates.contains(lower)) return true;
    if (lower.contains('-')) {
      final primary = lower.split('-').first;
      if (candidates.contains(primary)) return true;
    }
    return false;
  }

  dom.Element? _findLanguageStart(dom.Element root, String languageCode) {
    dom.Element? fallback;
    for (final child in root.children) {
      if (child.localName != 'h2') continue;
      fallback ??= child;
      if (_headingMatchesLanguage(child, languageCode)) {
        return child;
      }
    }
    return fallback;
  }

  bool _headingMatchesLanguage(dom.Element heading, String languageCode) {
    final marker = heading.querySelector(
      '.headline-lang[typeof="mw:Transclusion"]',
    );
    if (marker == null) return false;
    final dataMwRaw = marker.attributes['data-mw'];
    if (dataMwRaw == null) return false;
    try {
      final dynamic decoded = jsonDecode(dataMwRaw);
      return _dataMwContainsLang(decoded, languageCode);
    } catch (_) {
      return false;
    }
  }

  bool _dataMwContainsLang(dynamic node, String languageCode) {
    final code = languageCode.toLowerCase();
    if (node is Map<String, dynamic>) {
      for (final value in node.values) {
        if (_dataMwContainsLang(value, languageCode)) {
          return true;
        }
      }
    } else if (node is List) {
      for (final element in node) {
        if (_dataMwContainsLang(element, languageCode)) {
          return true;
        }
      }
    } else if (node is String) {
      final normalized = node.toLowerCase();
      if (normalized == code) return true;
      if (normalized.contains('-$code-')) return true;
      if (normalized.contains('"$code"')) return true;
      if (normalized.contains('{$code}')) return true;
      if (normalized.contains('=$code')) return true;
      if (normalized.contains('$code=')) return true;
      final pattern = RegExp(
        '(^|[^\\p{L}])${RegExp.escape(code)}([^\\p{L}]|\$)',
        unicode: true,
      );
      if (pattern.hasMatch(normalized)) {
        return true;
      }
    }
    return false;
  }

  dom.Element? _findNextLanguageHeading(dom.Element? start) {
    if (start == null) return null;
    var sibling = start.nextElementSibling;
    while (sibling != null) {
      if (sibling.localName == 'h2') {
        return sibling;
      }
      sibling = sibling.nextElementSibling;
    }
    return null;
  }

  List<dom.Element> _collectLanguageSlice(
    dom.Element root,
    dom.Element? start,
    dom.Element? end,
  ) {
    final elements = <dom.Element>[];
    dom.Element? node;
    if (start != null) {
      node = start.nextElementSibling;
    } else if (root.children.isNotEmpty) {
      node = root.children.first;
    }
    while (node != null && node != end) {
      elements.add(node);
      node = node.nextElementSibling;
    }
    return elements;
  }

  bool _looksLikeSenseDl(dom.Element dl) {
    if (_isInsideForbiddenContainer(dl)) return false;
    final dtElements =
        dl.children
            .whereType<dom.Element>()
            .where((element) => element.localName == 'dt')
            .toList();
    if (dtElements.isEmpty) return false;
    for (final dt in dtElements) {
      final label = dt.text.trim();
      if (!_isNumericLabel(label)) return false;
      final dd = _nextDefinitionElement(dt);
      if (dd == null) return false;
    }
    return true;
  }

  bool _isNumericLabel(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^\d+(?:\.\d+)*\.?$').hasMatch(normalized);
  }

  dom.Element? _nextDefinitionElement(dom.Element dt) {
    var sibling = dt.nextElementSibling;
    while (sibling != null) {
      if (sibling.localName == 'dd') return sibling;
      if (sibling.localName == 'dt') return null;
      sibling = sibling.nextElementSibling;
    }
    return null;
  }

  void _removeNodesBySelector(dom.Element root, String selector) {
    final nodes = root.querySelectorAll(selector).toList();
    for (final node in nodes) {
      node.remove();
    }
  }

  void _removeImmediateLists(dom.Element root) {
    final toRemove =
        root.children
            .whereType<dom.Element>()
            .where(
              (element) =>
                  element.localName == 'ul' || element.localName == 'ol',
            )
            .toList();
    for (final element in toRemove) {
      element.remove();
    }
  }

  void _removeElementsByClassSubstring(dom.Element root, String needle) {
    final target = needle.toLowerCase();
    final nodes =
        root.querySelectorAll('[class]').whereType<dom.Element>().toList();
    for (final element in nodes) {
      final matches = element.classes.any(
        (cls) => cls.toLowerCase().contains(target),
      );
      if (matches) {
        element.remove();
      }
    }
  }

  bool _isInsideForbiddenContainer(dom.Element element) {
    dom.Node? current = element;
    while (current != null) {
      if (current is dom.Element) {
        if (_forbiddenTags.contains(current.localName)) return true;
        if (current.attributes.containsKey('role') &&
            current.attributes['role']?.toLowerCase() == 'presentation') {
          return true;
        }
        if (current.attributes.containsKey('role') &&
            current.attributes['role']?.toLowerCase() == 'note') {
          return true;
        }
        for (final className in current.classes) {
          if (_forbiddenContainers.contains(className)) {
            return true;
          }
        }
        if (current.classes.contains('mw-parser-output')) {
          return false;
        }
      }
      current = current.parent;
    }
    return false;
  }

  String _cleanText(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    return collapsed.replaceAll(RegExp(r'\[\d+\]'), '').trim();
  }

  String _normalizeWord(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .replaceAll(RegExp(r'^[\p{P}\p{S}]+', unicode: true), '')
        .replaceAll(RegExp(r'[\p{P}\p{S}]+$', unicode: true), '')
        .trim();
  }

  String _cacheKey(String word, String lang, [String? sourceLang]) {
    final buffer =
        StringBuffer()
          ..write(word.toLowerCase())
          ..write('|')
          ..write(lang.toLowerCase());
    if (sourceLang != null && sourceLang.isNotEmpty) {
      buffer
        ..write('|')
        ..write(sourceLang.toLowerCase());
    }
    return buffer.toString();
  }

  bool _isExpired(_CacheEnvelope envelope, DateTime now) {
    return now.difference(envelope.storedAt) > _ttl;
  }

  Future<_CacheEnvelope?> _loadFromDisk(String key, DateTime now) async {
    final prefs = await _preferences();
    final raw = prefs.getString('$_prefsPrefix$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final entryJson = decoded['entry'];
      final storedAtString = decoded['storedAt'];
      if (entryJson is! Map<String, dynamic> || storedAtString is! String) {
        await prefs.remove('$_prefsPrefix$key');
        return null;
      }
      final entry = NativeDictionaryEntry.fromJson(entryJson);
      if (entry == null) {
        await prefs.remove('$_prefsPrefix$key');
        return null;
      }
      final storedAt = DateTime.tryParse(storedAtString);
      if (storedAt == null) {
        await prefs.remove('$_prefsPrefix$key');
        return null;
      }
      final envelope = _CacheEnvelope(entry: entry, storedAt: storedAt);
      if (_isExpired(envelope, now)) {
        await prefs.remove('$_prefsPrefix$key');
        return null;
      }
      return envelope;
    } catch (_) {
      await prefs.remove('$_prefsPrefix$key');
      return null;
    }
  }

  Future<void> _persistToDisk(String key, _CacheEnvelope envelope) async {
    final prefs = await _preferences();
    final payload = jsonEncode({
      'entry': envelope.entry.toJson(),
      'storedAt': envelope.storedAt.toIso8601String(),
    });
    await prefs.setString('$_prefsPrefix$key', payload);
  }

  Future<SharedPreferences> _preferences() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _toTitle(String raw) => raw;

  String _englishUrlForTitle(String title) {
    return 'https://en.wiktionary.org/wiki/${Uri.encodeComponent(title)}';
  }
}

class _SensePlan {
  const _SensePlan({
    required this.label,
    required this.languageCode,
    required this.url,
    this.preloadedDocument,
  });

  final String label;
  final String languageCode;
  final String url;
  final dom.Document? preloadedDocument;
}

class _Sense {
  const _Sense({required this.definition, this.examples = const []});

  final String definition;
  final List<String> examples;
}

class _SenseExtractionResult {
  const _SenseExtractionResult({
    this.definitions = const [],
    this.examples = const [],
    this.pos,
  });

  final List<String> definitions;
  final List<List<String>> examples;
  final String? pos;
}

class _FreeDictionaryResult {
  _FreeDictionaryResult({
    required this.englishTitle,
    required this.englishUrl,
    required this.englishDefinitions,
    required this.englishPos,
  });

  final String? englishTitle;
  final String? englishUrl;
  final List<String> englishDefinitions;
  final String? englishPos;

  factory _FreeDictionaryResult.empty(String query) {
    final title = query.isEmpty ? null : query;
    return _FreeDictionaryResult(
      englishTitle: title,
      englishUrl:
          title == null
              ? null
              : 'https://en.wiktionary.org/wiki/${Uri.encodeComponent(title)}',
      englishDefinitions: const [],
      englishPos: null,
    );
  }

  factory _FreeDictionaryResult.fromJson(
    dynamic decoded,
    String fallbackTitle,
  ) {
    if (decoded is! List) {
      return _FreeDictionaryResult.empty(fallbackTitle);
    }
    String? englishTitle;
    String? englishUrl;
    final definitions = <String>[];
    String? pos;

    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final source = entry['source'];
      if (source is Map<String, dynamic>) {
        final titleCandidate = source['title'];
        final urlCandidate = source['url'];
        if (titleCandidate is String && titleCandidate.isNotEmpty) {
          englishTitle ??= titleCandidate;
        }
        if (urlCandidate is String && urlCandidate.isNotEmpty) {
          englishUrl ??= urlCandidate;
        }
      }

      final meanings = entry['meanings'];
      if (meanings is List) {
        for (final meaning in meanings) {
          if (meaning is! Map<String, dynamic>) continue;
          final partOfSpeech = meaning['partOfSpeech'];
          if (partOfSpeech is String && partOfSpeech.isNotEmpty) {
            pos ??= partOfSpeech;
          }
          final defs = meaning['definitions'];
          if (defs is List) {
            for (final item in defs) {
              if (item is! Map<String, dynamic>) continue;
              final definition = item['definition'];
              if (definition is String && definition.trim().isNotEmpty) {
                definitions.add(definition.trim());
              }
            }
          }
        }
      }
    }

    englishTitle ??= fallbackTitle;
    englishUrl ??=
        'https://en.wiktionary.org/wiki/${Uri.encodeComponent(englishTitle)}';

    return _FreeDictionaryResult(
      englishTitle: englishTitle,
      englishUrl: englishUrl,
      englishDefinitions: definitions,
      englishPos: pos,
    );
  }
}

class _CacheEnvelope {
  _CacheEnvelope({required this.entry, required this.storedAt});

  final NativeDictionaryEntry entry;
  DateTime storedAt;
}

class _MemoryCache<K, V> {
  _MemoryCache({required this.capacity});

  final int capacity;
  final _store = LinkedHashMap<K, V>();

  V? get(K key) {
    final existing = _store.remove(key);
    if (existing == null) return null;
    _store[key] = existing;
    return existing;
  }

  void set(K key, V value) {
    if (_store.containsKey(key)) {
      _store.remove(key);
    } else if (_store.length >= capacity) {
      _store.remove(_store.keys.first);
    }
    _store[key] = value;
  }

  void remove(K key) {
    _store.remove(key);
  }
}
