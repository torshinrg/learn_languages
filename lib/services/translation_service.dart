import 'dart:async';
import 'dart:collection';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

class TranslationResult {
  TranslationResult({
    required this.text,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.cacheHit,
    this.latency,
    this.viaPivot = false,
  });

  final String text;
  final String sourceLanguage;
  final String targetLanguage;
  final bool cacheHit;
  final Duration? latency;
  final bool viaPivot;
}

enum TranslationErrorType {
  disabled,
  sameLanguage,
  network,
  client,
  server,
  timeout,
  configuration,
}

class TranslationException implements Exception {
  TranslationException(this.type, {this.statusCode, this.body, this.message});

  final TranslationErrorType type;
  final int? statusCode;
  final String? body;
  final String? message;

  @override
  String toString() {
    final parts = <String>['TranslationException($type)'];
    if (statusCode != null) parts.add('status=$statusCode');
    if (message != null && message!.isNotEmpty) parts.add(message!);
    return parts.join(' ');
  }
}

class TranslationService {
  TranslationService({
    required TranslatorConfig config,
    http.Client? client,
    Duration connectTimeout = const Duration(seconds: 8),
    Duration requestTimeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  }) : _config = config,
       _client = client ?? _createHttpClient(connectTimeout),
       _requestTimeout = requestTimeout,
       _clock = clock ?? DateTime.now;

  final TranslatorConfig _config;
  final http.Client _client;
  final Duration _requestTimeout;
  final DateTime Function() _clock;

  SharedPreferences? _prefs;

  static const Duration _ttl = Duration(days: 90);
  static const Duration _debounceWindow = Duration(milliseconds: 250);
  static const String _prefsPrefix = 'translation_cache:';

  final _MemoryCache _memoryCache = _MemoryCache(capacity: 512);
  final Map<String, Future<TranslationResult>> _inflight = {};
  final Map<String, DateTime> _lastNetworkRequest = {};

  static http.Client _createHttpClient(Duration connectTimeout) {
    if (kIsWeb) {
      return http.Client();
    }
    final HttpClient ioClient =
        HttpClient()..connectionTimeout = connectTimeout;
    return IOClient(ioClient);
  }

  Future<void> dispose() async {
    _client.close();
  }

  Future<TranslationResult> translate({
    required String query,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) {
    debugPrint(
      '[TranslationService] translate request: "${query.trim()}" '
      '(${sourceLanguageCode.toLowerCase()} → ${targetLanguageCode.toLowerCase()})',
    );
    return _translateInternal(
      query: query,
      sourceLanguageCode: sourceLanguageCode,
      targetLanguageCode: targetLanguageCode,
      allowPivot: true,
    );
  }

  Future<TranslationResult> _translateInternal({
    required String query,
    required String sourceLanguageCode,
    required String targetLanguageCode,
    required bool allowPivot,
  }) async {
    if (!_config.isEnabled) {
      throw TranslationException(
        TranslationErrorType.disabled,
        message: 'Translator disabled',
      );
    }

    final source = sourceLanguageCode.trim().toLowerCase();
    final target = targetLanguageCode.trim().toLowerCase();
    if (source.isEmpty || target.isEmpty) {
      throw TranslationException(
        TranslationErrorType.configuration,
        message: 'Missing language codes',
      );
    }
    if (source == target) {
      debugPrint(
        '[TranslationService] same-language request detected for $source. '
        'Skipping remote call.',
      );
      throw TranslationException(TranslationErrorType.sameLanguage);
    }

    final preparedQuery = _prepareQuery(query);
    if (preparedQuery.isEmpty) {
      throw TranslationException(
        TranslationErrorType.configuration,
        message: 'Empty query after normalization',
      );
    }

    final normalizedKey = _normalizeForCache(preparedQuery);
    final cacheKey = _cacheKey(normalizedKey, source, target);
    final now = _clock();

    final memoryEntry = _getFromMemory(cacheKey, now);
    if (memoryEntry != null) {
      debugPrint(
        '[TranslationService] cache hit (memory) for $source→$target '
        'key=$cacheKey',
      );
      return TranslationResult(
        text: memoryEntry.text,
        sourceLanguage: source,
        targetLanguage: target,
        cacheHit: true,
        latency: Duration.zero,
        viaPivot: memoryEntry.viaPivot,
      );
    }

    final diskEntry = await _loadFromDisk(cacheKey, now);
    if (diskEntry != null) {
      debugPrint(
        '[TranslationService] cache hit (disk) for $source→$target '
        'key=$cacheKey',
      );
      _memoryCache.set(cacheKey, diskEntry);
      return TranslationResult(
        text: diskEntry.text,
        sourceLanguage: source,
        targetLanguage: target,
        cacheHit: true,
        latency: Duration.zero,
        viaPivot: diskEntry.viaPivot,
      );
    }

    final existing = _inflight[cacheKey];
    if (existing != null) {
      return existing;
    }

    debugPrint(
      '[TranslationService] fetching remote translation key=$cacheKey',
    );
    final future = _fetchAndCache(
      cacheKey: cacheKey,
      preparedQuery: preparedQuery,
      source: source,
      target: target,
      allowPivot: allowPivot,
    );
    _inflight[cacheKey] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(cacheKey);
    }
  }

  Future<TranslationResult> _fetchAndCache({
    required String cacheKey,
    required String preparedQuery,
    required String source,
    required String target,
    required bool allowPivot,
  }) async {
    final now = _clock();
    final last = _lastNetworkRequest[cacheKey];
    if (last != null) {
      final diff = now.difference(last);
      if (diff < _debounceWindow) {
        await Future.delayed(_debounceWindow - diff);
      }
    }
    _lastNetworkRequest[cacheKey] = _clock();

    final outcome = await _performFetch(
      preparedQuery: preparedQuery,
      source: source,
      target: target,
      allowPivot: allowPivot,
    );

    final entry = _CacheEntry(
      text: outcome.entry.text,
      storedAt: _clock(),
      viaPivot: outcome.entry.viaPivot,
    );
    _memoryCache.set(cacheKey, entry);
    unawaited(_persistToDisk(cacheKey, entry));
    debugPrint(
      '[TranslationService] remote result $source→$target key=$cacheKey '
      'viaPivot=${outcome.viaPivot} latency=${outcome.latency.inMilliseconds}ms',
    );

    return TranslationResult(
      text: entry.text,
      sourceLanguage: source,
      targetLanguage: target,
      cacheHit: false,
      latency: outcome.latency,
      viaPivot: entry.viaPivot,
    );
  }

  Future<_FetchOutcome> _performFetch({
    required String preparedQuery,
    required String source,
    required String target,
    required bool allowPivot,
  }) async {
    final endpoint = _config.translateEndpoint();
    if (endpoint == null) {
      throw TranslationException(
        TranslationErrorType.disabled,
        message: 'Translator endpoint not configured',
      );
    }

    final headers = <String, String>{'Content-Type': 'application/json'};
    if (_config.hasApiKey) {
      headers['Authorization'] = 'Bearer ${_config.apiKey}';
    }

    try {
      final requestOutcome = await _executeRequest(
        endpoint: endpoint,
        headers: headers,
        body: {
          'q': preparedQuery,
          'source': source,
          'target': target,
          'format': 'text',
        },
        includeApiKeyField: false,
      );
      return _FetchOutcome(
        entry: _CacheEntry(
          text: requestOutcome.entry.text,
          storedAt: requestOutcome.entry.storedAt,
          viaPivot: false,
        ),
        viaPivot: false,
        latency: requestOutcome.duration,
      );
    } on TranslationException catch (error) {
      debugPrint(
        '[TranslationService] request error type=${error.type} '
        'status=${error.statusCode} body=${error.body}',
      );
      final shouldPivot =
          allowPivot &&
          error.type == TranslationErrorType.client &&
          error.statusCode == 400;
      if (!shouldPivot) {
        rethrow;
      }
      if (source == 'en' || target == 'en') {
        rethrow;
      }
      final pivotOutcome = await _pivotViaEnglish(
        originalQuery: preparedQuery,
        source: source,
        target: target,
      );
      return pivotOutcome;
    }
  }

  Future<_FetchOutcome> _pivotViaEnglish({
    required String originalQuery,
    required String source,
    required String target,
  }) async {
    const pivotLang = 'en';
    final first = await _translateInternal(
      query: originalQuery,
      sourceLanguageCode: source,
      targetLanguageCode: pivotLang,
      allowPivot: false,
    );
    debugPrint(
      '[TranslationService] pivot step $source→$pivotLang produced "${first.text}"',
    );
    final intermediate = first.text.trim();
    final second = await _translateInternal(
      query: intermediate.isEmpty ? originalQuery : intermediate,
      sourceLanguageCode: pivotLang,
      targetLanguageCode: target,
      allowPivot: false,
    );
    debugPrint(
      '[TranslationService] pivot step $pivotLang→$target produced "${second.text}"',
    );

    final segments =
        <String>[
          intermediate,
          second.text.trim(),
        ].where((segment) => segment.isNotEmpty).toList();
    final seen = <String>{};
    final ordered = <String>[];
    for (final segment in segments) {
      if (seen.add(segment)) {
        ordered.add(segment);
      }
    }
    final combinedText = ordered.join('\n');
    final latency =
        (first.latency ?? Duration.zero) + (second.latency ?? Duration.zero);

    return _FetchOutcome(
      entry: _CacheEntry(
        text: combinedText.isEmpty ? second.text : combinedText,
        storedAt: _clock(),
        viaPivot: true,
      ),
      viaPivot: true,
      latency: latency,
    );
  }

  Future<_RequestOutcome> _executeRequest({
    required Uri endpoint,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    required bool includeApiKeyField,
  }) async {
    final payload = Map<String, dynamic>.from(body);
    if (includeApiKeyField && _config.hasApiKey) {
      payload['api_key'] = _config.apiKey;
    }

    final start = _clock();
    http.Response response;
    try {
      response = await _client
          .post(endpoint, headers: headers, body: jsonEncode(payload))
          .timeout(_requestTimeout);
    } on TimeoutException {
      debugPrint('[TranslationService] timeout contacting $endpoint');
      throw TranslationException(TranslationErrorType.timeout);
    } on SocketException catch (error) {
      debugPrint('[TranslationService] socket error: ${error.message}');
      throw TranslationException(
        TranslationErrorType.network,
        message: error.message,
      );
    } on http.ClientException catch (error) {
      debugPrint('[TranslationService] client exception: ${error.message}');
      throw TranslationException(
        TranslationErrorType.network,
        message: error.message,
      );
    }

    if (response.statusCode == 401 &&
        _config.hasApiKey &&
        !includeApiKeyField) {
      debugPrint(
        '[TranslationService] received 401, retrying with api_key field',
      );
      return _executeRequest(
        endpoint: endpoint,
        headers: headers,
        body: body,
        includeApiKeyField: true,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final text = _extractTranslatedText(response.body);
        return _RequestOutcome(
          entry: _CacheEntry(text: text, storedAt: _clock()),
          duration: _clock().difference(start),
        );
      } on TranslationException {
        rethrow;
      } on FormatException {
        debugPrint(
          '[TranslationService] malformed response body: ${response.body}',
        );
        throw TranslationException(
          TranslationErrorType.server,
          message: 'Malformed translation response',
        );
      }
    }

    if (response.statusCode >= 500) {
      debugPrint('[TranslationService] server response ${response.statusCode}');
      throw TranslationException(
        TranslationErrorType.server,
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      debugPrint(
        '[TranslationService] client error ${response.statusCode}: ${response.body}',
      );
      throw TranslationException(
        TranslationErrorType.client,
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    throw TranslationException(
      TranslationErrorType.server,
      statusCode: response.statusCode,
    );
  }

  _CacheEntry? _getFromMemory(String key, DateTime now) {
    final entry = _memoryCache.get(key);
    if (entry == null) return null;
    if (_isExpired(entry, now)) {
      _memoryCache.remove(key);
      return null;
    }
    entry.storedAt = now;
    _memoryCache.set(key, entry);
    unawaited(_persistToDisk(key, entry));
    return entry;
  }

  bool _isExpired(_CacheEntry entry, DateTime now) {
    return now.difference(entry.storedAt) > _ttl;
  }

  Future<_CacheEntry?> _loadFromDisk(String key, DateTime now) async {
    final prefs = await _preferences();
    final raw = prefs.getString('$_prefsPrefix$key');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(map);
      if (entry == null) {
        await prefs.remove('$_prefsPrefix$key');
        return null;
      }
      if (_isExpired(entry, now)) {
        await prefs.remove('$_prefsPrefix$key');
        return null;
      }
      entry.storedAt = now;
      await prefs.setString('$_prefsPrefix$key', jsonEncode(entry.toJson()));
      return entry;
    } catch (_) {
      await prefs.remove('$_prefsPrefix$key');
      return null;
    }
  }

  Future<void> _persistToDisk(String key, _CacheEntry entry) async {
    final prefs = await _preferences();
    await prefs.setString('$_prefsPrefix$key', jsonEncode(entry.toJson()));
  }

  Future<SharedPreferences> _preferences() async {
    if (_prefs != null) return _prefs!;
    _prefs = await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _prepareQuery(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final leading = RegExp(r'^[\p{P}\p{S}]+', unicode: true);
    final trailing = RegExp(r'[\p{P}\p{S}]+$', unicode: true);
    final withoutLeading = trimmed.replaceFirst(leading, '');
    final withoutTrailing = withoutLeading.replaceFirst(trailing, '');
    final candidate = withoutTrailing.trim();
    return candidate.isEmpty ? trimmed : candidate;
  }

  String _normalizeForCache(String prepared) {
    return prepared.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cacheKey(String normalizedQuery, String source, String target) {
    final raw =
        '${normalizedQuery.toLowerCase()}|${source.toLowerCase()}|${target.toLowerCase()}';
    final digest = sha256.convert(utf8.encode(raw));
    return digest.toString();
  }

  String _extractTranslatedText(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw TranslationException(
        TranslationErrorType.server,
        message: 'Unexpected translation payload',
      );
    }
    final value = decoded['translatedText'];
    if (value is String) {
      return value.trim();
    }
    if (value is List) {
      final parts =
          value
              .map(
                (element) => (element == null ? '' : element.toString().trim()),
              )
              .where((element) => element.isNotEmpty)
              .toList();
      if (parts.isNotEmpty) {
        return parts.join('\n');
      }
    }
    throw TranslationException(
      TranslationErrorType.server,
      message: 'Missing translatedText field',
    );
  }
}

class _CacheEntry {
  _CacheEntry({
    required this.text,
    required this.storedAt,
    this.viaPivot = false,
  });

  String text;
  DateTime storedAt;
  bool viaPivot;

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'storedAt': storedAt.toIso8601String(),
      'viaPivot': viaPivot,
    };
  }

  static _CacheEntry? fromJson(Map<String, dynamic> map) {
    final textRaw = map['text'];
    final storedAtRaw = map['storedAt'];
    if (textRaw is! String || storedAtRaw is! String) {
      return null;
    }
    final timestamp = DateTime.tryParse(storedAtRaw);
    if (timestamp == null) return null;
    final viaPivot = map['viaPivot'] == true;
    return _CacheEntry(text: textRaw, storedAt: timestamp, viaPivot: viaPivot);
  }
}

class _MemoryCache {
  _MemoryCache({required this.capacity});

  final int capacity;
  final _store = LinkedHashMap<String, _CacheEntry>();

  _CacheEntry? get(String key) {
    final entry = _store.remove(key);
    if (entry == null) return null;
    _store[key] = entry;
    return entry;
  }

  void set(String key, _CacheEntry entry) {
    if (_store.containsKey(key)) {
      _store.remove(key);
    } else if (_store.length >= capacity) {
      final oldestKey = _store.keys.first;
      _store.remove(oldestKey);
    }
    _store[key] = entry;
  }

  void remove(String key) {
    _store.remove(key);
  }
}

class _RequestOutcome {
  _RequestOutcome({required this.entry, required this.duration});

  final _CacheEntry entry;
  final Duration duration;
}

class _FetchOutcome {
  _FetchOutcome({
    required this.entry,
    required this.viaPivot,
    required this.latency,
  });

  final _CacheEntry entry;
  final bool viaPivot;
  final Duration latency;
}
