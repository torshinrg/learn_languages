import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/di.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/user_word_status.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/i_sentence_repository.dart';
import '../../services/native_dictionary_service.dart';
import '../providers/reader_provider.dart';
import '../providers/settings_provider.dart';

class WordBottomSheet extends StatefulWidget {
  const WordBottomSheet({
    super.key,
    required this.lookupResult,
    required this.onStatusSelected,
  });

  final WordLookupResult lookupResult;
  final Future<void> Function(WordStatus status) onStatusSelected;

  @override
  State<WordBottomSheet> createState() => _WordBottomSheetState();
}

class _WordBottomSheetState extends State<WordBottomSheet> {
  late Future<List<Sentence>> _examplesFuture;
  Future<NativeDictionaryEntry>? _dictionaryFuture;
  WordStatus? _selectedStatus;
  String? _nativeLanguageCode;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.lookupResult.status?.status;
    _examplesFuture = _loadExamples();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    final native = _resolveNativeLanguage(settings);
    if (_dictionaryFuture == null || native != _nativeLanguageCode) {
      final future = _loadDictionaryEntry(native);
      setState(() {
        _nativeLanguageCode = native;
        _dictionaryFuture = future;
      });
    }
  }

  Widget build(BuildContext context) {
    final word = widget.lookupResult.word;
    final token = widget.lookupResult.token;
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final headerText = token.text;

    return FractionallySizedBox(
      heightFactor: 0.75,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final availableHeight = constraints.maxHeight;
            final examplesHeight =
                word == null
                    ? 0.0
                    : (availableHeight * 0.4)
                        .clamp(160.0, availableHeight * 0.6)
                        .toDouble();

            final content = <Widget>[
              Text(headerText, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              _buildDictionarySection(loc),
              const SizedBox(height: 24),
            ];

            if (word == null) {
              content.add(Text(loc.readerWordMissing));
            } else {
              content
                ..add(
                  Text(
                    loc.readerAddToVocabulary,
                    style: theme.textTheme.titleMedium,
                  ),
                )
                ..add(const SizedBox(height: 12))
                ..add(
                  Wrap(
                    spacing: 8,
                    children:
                        WordStatus.values
                            .map(
                              (status) => ChoiceChip(
                                label: Text(_labelForStatus(loc, status)),
                                selected: _selectedStatus == status,
                                onSelected: (_) async {
                                  setState(() => _selectedStatus = status);
                                  await widget.onStatusSelected(status);
                                },
                              ),
                            )
                            .toList(),
                  ),
                )
                ..add(const SizedBox(height: 24))
                ..add(
                  Text(loc.readerExamples, style: theme.textTheme.titleMedium),
                )
                ..add(const SizedBox(height: 12))
                ..add(
                  _buildExamplesSection(
                    height: examplesHeight,
                    loc: loc,
                    theme: theme,
                  ),
                );
            }

            return Scrollbar(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: bottomInset + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDictionarySection(AppLocalizations loc) {
    final theme = Theme.of(context);
    final future = _dictionaryFuture;
    if (future == null) {
      return _DictionaryErrorBanner(
        message: loc.readerDictionaryError,
        retryLabel: loc.readerDictionaryRetry,
        onRetry: _retryDictionary,
      );
    }
    return FutureBuilder<NativeDictionaryEntry>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              const SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc.readerDictionaryLoading,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return _DictionaryErrorBanner(
            message: loc.readerDictionaryError,
            retryLabel: loc.readerDictionaryRetry,
            onRetry: _retryDictionary,
          );
        }
        final entry = snapshot.data;
        if (entry == null) {
          return _DictionaryErrorBanner(
            message: loc.readerDictionaryError,
            retryLabel: loc.readerDictionaryRetry,
            onRetry: _retryDictionary,
          );
        }
        return _buildDictionaryContent(entry, loc);
      },
    );
  }

  Widget _buildDictionaryContent(
    NativeDictionaryEntry entry,
    AppLocalizations loc,
  ) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final isTranslation = entry.sourceLang == 'translate';
    final title =
        isTranslation
            ? loc.readerDictionaryTranslation
            : loc.readerDictionaryTitle;
    final sourceChip = _sourceChipLabel(entry, loc);
    final sections = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: textTheme.titleMedium),
          if (sourceChip != null)
            Chip(
              label: Text(sourceChip),
              backgroundColor: theme.colorScheme.surfaceVariant,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    ];

    if (!isTranslation && entry.pos != null && entry.pos!.trim().isNotEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Chip(
            label: Text(entry.pos!.trim()),
            backgroundColor: theme.colorScheme.surfaceVariant,
            visualDensity: VisualDensity.compact,
          ),
        ),
      );
    }

    sections.add(const SizedBox(height: 12));

    if (isTranslation) {
      if (entry.translation != null && entry.translation!.isNotEmpty) {
        sections.add(Text(entry.translation!, style: textTheme.bodyLarge));
      } else {
        sections.add(
          Text(loc.readerDictionaryNoDefinitions, style: textTheme.bodySmall),
        );
      }
    } else if (entry.definitions.isNotEmpty) {
      sections.addAll(_buildDefinitionList(entry.definitions, textTheme));
    } else {
      sections.add(
        Text(loc.readerDictionaryNoDefinitions, style: textTheme.bodySmall),
      );
    }

    if (!isTranslation && entry.pronunciations.isNotEmpty) {
      sections
        ..add(const SizedBox(height: 16))
        ..add(
          Text(loc.readerDictionaryPronunciations, style: textTheme.titleSmall),
        )
        ..add(const SizedBox(height: 8))
        ..add(_buildChipWrap(entry.pronunciations, theme));
    }

    if (!isTranslation && entry.synonyms.isNotEmpty) {
      sections
        ..add(const SizedBox(height: 16))
        ..add(Text(loc.readerDictionarySynonyms, style: textTheme.titleSmall))
        ..add(const SizedBox(height: 8))
        ..add(_buildChipWrap(entry.synonyms, theme));
    }

    if (!isTranslation && entry.antonyms.isNotEmpty) {
      sections
        ..add(const SizedBox(height: 16))
        ..add(Text(loc.readerDictionaryAntonyms, style: textTheme.titleSmall))
        ..add(const SizedBox(height: 8))
        ..add(_buildChipWrap(entry.antonyms, theme));
    }

    if (!isTranslation &&
        entry.etymology != null &&
        entry.etymology!.isNotEmpty) {
      sections
        ..add(const SizedBox(height: 16))
        ..add(Text(loc.readerDictionaryEtymology, style: textTheme.titleSmall))
        ..add(const SizedBox(height: 4))
        ..add(Text(entry.etymology!, style: textTheme.bodyMedium));
    }

    sections
      ..add(const SizedBox(height: 16))
      ..add(_buildAttribution(entry, theme, loc));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  List<Widget> _buildDefinitionList(
    List<String> definitions,
    TextTheme textTheme,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < definitions.length; i++) {
      final definition = definitions[i];
      widgets.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i == definitions.length - 1 ? 0 : 12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}. ',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(child: Text(definition, style: textTheme.bodyMedium)),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildChipWrap(List<String> items, ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children:
          items
              .map(
                (item) => Chip(
                  label: Text(item),
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(),
    );
  }

  Widget _buildAttribution(
    NativeDictionaryEntry entry,
    ThemeData theme,
    AppLocalizations loc,
  ) {
    final attributionStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.6),
    );
    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    if (entry.sourceLang == 'translate') {
      return Text(
        loc.readerDictionaryTranslationAttribution,
        style: attributionStyle,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.sourceUrl != null && entry.sourceUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _launchSourceUrl(entry.sourceUrl!),
              child: Text(entry.sourceUrl!, style: linkStyle),
            ),
          ),
        Text(
          'Wiktionary (CC-BY-SA/GFDL) • FreeDictionaryAPI',
          style: attributionStyle,
        ),
      ],
    );
  }

  String? _sourceChipLabel(NativeDictionaryEntry entry, AppLocalizations loc) {
    final source = entry.sourceLang?.toLowerCase().trim();
    if (source == null || source.isEmpty) return null;
    if (source == 'translate') return null;
    if (source == 'user') {
      final targetCode = entry.targetLang.toLowerCase();
      final shortCode = targetCode.split('-').first;
      return _languageDisplayName(shortCode);
    }
    if (source == entry.targetLang.toLowerCase()) return null;
    if (source == 'en') {
      return loc.readerDictionaryFallback;
    }
    return _languageDisplayName(source);
  }

  String _languageDisplayName(String code) {
    const names = <String, String>{
      'es': 'Español',
      'ru': 'Русский',
      'fr': 'Français',
      'de': 'Deutsch',
      'it': 'Italiano',
      'pt': 'Português',
    };
    return names[code] ?? code.toUpperCase();
  }

  Widget _buildExamplesSection({
    required double height,
    required AppLocalizations loc,
    required ThemeData theme,
  }) {
    return SizedBox(
      height: height,
      child: FutureBuilder<List<Sentence>>(
        future: _examplesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                height: 28,
                width: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                loc.readerExamplesEmpty,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            );
          }
          final sentences = snapshot.data ?? const <Sentence>[];
          if (sentences.isEmpty) {
            return Center(
              child: Text(
                loc.readerExamplesEmpty,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.separated(
            primary: false,
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            itemCount: sentences.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final sentence = sentences[index];
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    sentence.content,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Sentence>> _loadExamples() async {
    final word = widget.lookupResult.word;
    if (word == null) return const [];
    try {
      final repo = getIt<ISentenceRepository>();
      return repo.fetchByWord(word.id);
    } catch (_) {
      return const [];
    }
  }

  Future<NativeDictionaryEntry> _loadDictionaryEntry(String nativeLang) {
    final dictionary = getIt<NativeDictionaryService>();
    final token = widget.lookupResult.token;
    final lemmaCandidate =
        widget.lookupResult.token.lemma ?? widget.lookupResult.word?.text;
    final sourceLangCode = (token.languageCode ?? '').trim().toLowerCase();
    return dictionary.lookup(
      word: token.text,
      targetLang: nativeLang,
      lemma: lemmaCandidate,
      sourceLang: sourceLangCode.isEmpty ? null : sourceLangCode,
    );
  }

  void _retryDictionary() {
    final settings = context.read<SettingsProvider>();
    final native = _resolveNativeLanguage(settings);
    setState(() {
      _nativeLanguageCode = native;
      _dictionaryFuture = _loadDictionaryEntry(native);
    });
  }

  String _resolveNativeLanguage(SettingsProvider settings) {
    final native = settings.nativeLanguageCode;
    if (native != null && native.isNotEmpty) {
      return native.toLowerCase();
    }
    if (settings.learningLanguageCodes.isNotEmpty) {
      return settings.learningLanguageCodes.first.toLowerCase();
    }
    return 'en';
  }

  Future<void> _launchSourceUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await launchUrlString(url);
    } catch (_) {
      // Ignored—link opening failures should not crash the sheet.
    }
  }

  String _labelForStatus(AppLocalizations loc, WordStatus status) {
    switch (status) {
      case WordStatus.New:
        return loc.readerStatusNew;
      case WordStatus.inProgress:
        return loc.readerStatusLearning;
      case WordStatus.known:
        return loc.readerStatusKnown;
    }
  }
}

class _DictionaryErrorBanner extends StatelessWidget {
  const _DictionaryErrorBanner({
    required this.message,
    required this.retryLabel,
    this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            ActionChip(label: Text(retryLabel), onPressed: onRetry),
        ],
      ),
    );
  }
}
