import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:learn_languages/core/app_config.dart';
import 'package:learn_languages/services/native_dictionary_service.dart';
import 'package:learn_languages/services/translation_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NativeDictionaryService', () {
    const freedictResponse = '''
[
  {
    "word": "test",
    "source": {
      "title": "Test",
      "url": "https://en.wiktionary.org/wiki/Test"
    },
    "meanings": [
      {
        "partOfSpeech": "noun",
        "definitions": [
          {"definition": "A procedure intended to establish the quality."}
        ]
      }
    ]
  }
]
''';

    test('prefers user language dl senses and strips noise', () async {
      const englishUrl = 'https://en.wiktionary.org/wiki/Test';
      const userUrl = 'https://es.wiktionary.org/wiki/Test';
      const englishHtml = '''
<!DOCTYPE html>
<html><body>
  <nav id="p-lang-btn">
    <div class="vector-menu-content-list">
      <li class="interlanguage-link interwiki-es">
        <a href="$userUrl" hreflang="es">Español</a>
      </li>
    </div>
  </nav>
  <div class="mw-parser-output">
    <h2><span class="mw-headline" lang="en" id="English">English</span></h2>
  </div>
</body></html>
''';

      const userHtml = '''
<!DOCTYPE html>
<html><body>
  <div class="mw-parser-output">
    <h2><span class="mw-headline" lang="es" id="Español">Español</span></h2>
    <div class="mw-heading"><h3>Sustantivo</h3></div>
    <dl>
      <dt>1</dt>
      <dd>Casa <sup class="mw-ref reference">[1]</sup></dd>
      <dt>2</dt>
      <dd>Hogar
        <ul><li>Ejemplo: Vivo en una casa grande.</li></ul>
      </dd>
    </dl>
  </div>
</body></html>
''';

      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('freedictionaryapi.com')) {
          return http.Response(freedictResponse, 200);
        }
        if (url == englishUrl) {
          return http.Response(englishHtml, 200);
        }
        if (url == userUrl) {
          return http.Response(userHtml, 200);
        }
        return http.Response('not found', 404);
      });

      final service = NativeDictionaryService(client: client);
      final entry = await service.lookup(
        word: 'Test',
        targetLang: 'es',
        lemma: 'test',
      );
      expect(entry.sourceLang, 'user');
      expect(entry.sourceUrl, userUrl);
      expect(entry.definitions, ['Casa', 'Hogar']);
      expect(entry.examples.length, 2);
      expect(entry.examples[0], isEmpty);
      expect(entry.examples[1], ['Vivo en una casa grande.']);
      await service.dispose();
    });

    test('falls back to english when user slice empty', () async {
      const englishUrl = 'https://en.wiktionary.org/wiki/Test';
      const englishHtml = '''
<!DOCTYPE html>
<html><body>
  <nav id="p-lang-btn">
    <div class="vector-menu-content-list">
      <li class="interlanguage-link interwiki-it">
        <a href="https://it.wiktionary.org/wiki/Test" hreflang="it">Italiano</a>
      </li>
    </div>
  </nav>
  <div class="mw-parser-output">
    <h2><span class="mw-headline" lang="en" id="English">English</span></h2>
    <div class="mw-heading"><h3>Noun</h3></div>
    <dl>
      <dt>1</dt>
      <dd>A procedure intended to establish the quality of something.</dd>
    </dl>
  </div>
</body></html>
''';

      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('freedictionaryapi.com')) {
          return http.Response(freedictResponse, 200);
        }
        if (url == englishUrl) {
          return http.Response(englishHtml, 200);
        }
        return http.Response('not found', 404);
      });

      final service = NativeDictionaryService(client: client);
      final entry = await service.lookup(
        word: 'Test',
        targetLang: 'fr',
        lemma: 'test',
      );
      expect(entry.sourceLang, 'en');
      expect(entry.sourceUrl, englishUrl);
      expect(entry.definitions, [
        'A procedure intended to establish the quality of something.',
      ]);
      expect(entry.examples.single, isEmpty);
      await service.dispose();
    });

    test(
      'uses English wiktionary senses before translation when freedict empty',
      () async {
        const englishUrl = 'https://en.wiktionary.org/wiki/Test';
        const englishHtml = '''
<!DOCTYPE html>
<html><body>
  <div class="mw-parser-output">
    <h2><span class="mw-headline" lang="en" id="English">English</span></h2>
    <div class="mw-heading"><h3>Noun</h3></div>
    <ol>
      <li>A procedure intended to establish quality.</li>
      <li>School exam.</li>
    </ol>
  </div>
</body></html>
''';

        final client = MockClient((request) async {
          final url = request.url.toString();
          if (url.contains('freedictionaryapi.com')) {
            return http.Response('[]', 200);
          }
          if (url == englishUrl) {
            return http.Response(englishHtml, 200);
          }
          return http.Response('not found', 404);
        });

        final translator = _FakeTranslationService('Haus');
        final service = NativeDictionaryService(
          client: client,
          translationService: translator,
        );
        final entry = await service.lookup(
          word: 'Test',
          targetLang: 'en',
          lemma: 'test',
        );
        expect(entry.sourceLang, 'en');
        expect(entry.translation, isNull);
        expect(entry.definitions, [
          'A procedure intended to establish quality.',
          'School exam.',
        ]);
        expect(translator.lastQuery, isNull);
        await service.dispose();
      },
    );

    test('translates when no senses available', () async {
      const englishUrl = 'https://en.wiktionary.org/wiki/Test';
      const englishHtml = '''
<!DOCTYPE html>
<html><body>
  <div class="mw-parser-output">
    <h2><span class="mw-headline" lang="en" id="English">English</span></h2>
    <table class="wikitable"><tr><td>Conjugation table</td></tr></table>
    <div class="references">
      <ol>
        <li><a href="#cite_note-1">[1]</a> Some reference</li>
        <li><a href="#cite_note-2">[2]</a> Another reference</li>
      </ol>
    </div>
  </div>
</body></html>
''';

      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url.contains('freedictionaryapi.com')) {
          final payload = [
            {
              'word': 'test',
              'source': {'title': 'Test', 'url': englishUrl},
              'meanings': const [],
            },
          ];
          return http.Response(jsonEncode(payload), 200);
        }
        if (url == englishUrl) {
          return http.Response(englishHtml, 200);
        }
        return http.Response('not found', 404);
      });

      final translator = _FakeTranslationService('Haus');
      final service = NativeDictionaryService(
        client: client,
        translationService: translator,
      );
      final entry = await service.lookup(
        word: 'Test',
        targetLang: 'de',
        lemma: 'test',
        sourceLang: 'en',
      );
      expect(entry.sourceLang, 'translate');
      expect(entry.translation, 'Haus');
      expect(entry.definitions, isEmpty);
      expect(entry.examples, isEmpty);
      expect(translator.lastSourceLanguage, 'en');
      expect(translator.lastTargetLanguage, 'de');
      await service.dispose();
    });
  });
}

class _FakeTranslationService extends TranslationService {
  _FakeTranslationService(this._text)
    : super(
        config: TranslatorConfig(baseUrl: 'https://fake'),
        client: MockClient((_) async => http.Response('', 500)),
      );

  final String _text;
  String? lastQuery;
  String? lastSourceLanguage;
  String? lastTargetLanguage;

  @override
  Future<TranslationResult> translate({
    required String query,
    required String sourceLanguageCode,
    required String targetLanguageCode,
  }) async {
    lastQuery = query;
    lastSourceLanguage = sourceLanguageCode;
    lastTargetLanguage = targetLanguageCode;
    return TranslationResult(
      text: _text,
      sourceLanguage: sourceLanguageCode,
      targetLanguage: targetLanguageCode,
      cacheHit: false,
    );
  }
}
