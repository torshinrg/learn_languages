import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../../core/di.dart';
import '../../../data/remote/appwrite_service.dart';
import '../../../data/local/reading_progress_store.dart';
import '../../../domain/entities/material_sentence.dart';
import '../../../domain/entities/reading_material.dart';
import '../../../domain/entities/sentence.dart';
import '../../../domain/entities/user_word_status.dart';
import '../../../domain/entities/task.dart';
import '../../../domain/repositories/i_material_sentence_repository.dart';
import '../../../domain/repositories/i_reading_material_repository.dart';
import '../../../domain/repositories/i_user_word_status_repository.dart';
import '../../../domain/repositories/i_word_repository.dart';
import '../../../domain/repositories/i_task_repository.dart';
import '../../../domain/repositories/i_task_translation_repository.dart';
import '../../../domain/repositories/i_language_repository.dart';
import '../../providers/settings_provider.dart';
import '../../providers/reader_provider.dart';
import '../../widgets/tokenized_sentence.dart';
import '../../widgets/word_bottom_sheet.dart';

class ReaderScreenArguments {
  const ReaderScreenArguments({required this.materialId, this.material});

  final String materialId;
  final ReadingMaterial? material;
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.materialId, this.material});

  final String materialId;
  final ReadingMaterial? material;

  static const routeName = '/reading/detail';

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pageController;
  bool _pageUpdateFromController = false;
  bool _suppressTapToggle = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReaderProvider>(
      create:
          (ctx) => ReaderProvider(
            materialId: widget.materialId,
            materialRepository: getIt<IReadingMaterialRepository>(),
            materialSentenceRepository: getIt<IMaterialSentenceRepository>(),
            wordRepository: getIt<IWordRepository>(),
            userWordStatusRepository: getIt<IUserWordStatusRepository>(),
            progressStore: getIt<ReadingProgressStore>(),
            appwriteService: getIt<AppwriteService>(),
            taskRepository: getIt<ITaskRepository>(),
            taskTranslationRepository: getIt<ITaskTranslationRepository>(),
            languageRepository: getIt<ILanguageRepository>(),
            settingsProvider: ctx.read<SettingsProvider>(),
          )..init(material: widget.material),
      child: Consumer<ReaderProvider>(
        builder: (context, provider, _) {
          _syncPageController(provider);
          final material = provider.material;
          final loc = AppLocalizations.of(context)!;
          final title = material?.title ?? loc.readingTitle;
          final hasContent = provider.sentenceCount > 0;
          final isResuming = provider.isResuming;
          final progressValue = provider.progressPercent();
          final progressIndicatorValue =
              progressValue.isFinite ? progressValue.clamp(0.0, 1.0) : 0.0;

          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body:
                provider.isLoading && !hasContent
                    ? const Center(child: CircularProgressIndicator())
                    : isResuming
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                      children: [
                        if (provider.errorMessage != null && hasContent)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              loc.readerLoadingWarning,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        Expanded(
                          child:
                              hasContent
                                  ? PageView.builder(
                                    controller: _pageController,
                                    scrollDirection: Axis.vertical,
                                    onPageChanged: (index) {
                                      _pageUpdateFromController = true;
                                      provider.jumpToSentence(
                                        index,
                                        autoPlay: true,
                                      );
                                      if (index >= provider.sentenceCount - 2) {
                                        provider.loadMore();
                                      }
                                      _pageUpdateFromController = false;
                                    },
                                    itemCount: provider.sentenceCount,
                                    itemBuilder: (context, index) {
                                      return FutureBuilder<SentenceViewData?>(
                                        future: provider.ensureViewForIndex(
                                          index,
                                        ),
                                        builder: (context, snapshot) {
                                          if (!snapshot.hasData) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          final data = snapshot.data!;
                                          if (provider.autoplayPending &&
                                              index == provider.currentIndex) {
                                            WidgetsBinding.instance
                                                .addPostFrameCallback((_) {
                                                  if (!mounted) return;
                                                  provider
                                                      .playCurrentSentence();
                                                });
                                          }
                                          return GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap:
                                                () =>
                                                    _handleReaderTap(provider),
                                            child: Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  TokenizedSentence(
                                                    data: data,
                                                    onTokenTap:
                                                        (token) =>
                                                            _handleTokenTap(
                                                              context,
                                                              token,
                                                            ),
                                                  ),
                                                  if (data
                                                      .tasks
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 24),
                                                    _SentenceTaskColumn(
                                                      tasks: data.tasks,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  )
                                  : Center(
                                    child: Text(
                                      provider.errorMessage != null
                                          ? loc.readerLoadingWarning
                                          : loc.readerNoSentences,
                                    ),
                                  ),
                        ),
                        if (hasContent)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${provider.currentIndex + 1} / ${provider.totalSentences > 0 ? provider.totalSentences : '?'}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: progressIndicatorValue,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
          );
        },
      ),
    );
  }

  void _handleReaderTap(ReaderProvider provider) {
    if (_suppressTapToggle) {
      _suppressTapToggle = false;
      return;
    }
    final sentence = provider.currentSentence?.sentence;
    final hasAudio =
        sentence != null &&
        ((sentence.audioId != null && sentence.audioId!.isNotEmpty) ||
            (sentence.audioUrl != null && sentence.audioUrl!.isNotEmpty));
    if (!hasAudio) {
      return;
    }
    if (provider.isAudioPlaying) {
      provider.pause();
    } else {
      provider.playCurrentSentence();
    }
  }

  Future<void> _handleTokenTap(
    BuildContext context,
    SentenceTokenData token,
  ) async {
    _suppressTapToggle = true;
    try {
      await _showWordSheet(context, token);
    } finally {
      _suppressTapToggle = false;
    }
  }

  void _syncPageController(ReaderProvider provider) {
    if (!provider.isInitialized) return;
    if (!_pageController.hasClients) return;
    if (provider.sentenceCount == 0) return;
    if (_pageUpdateFromController) return;
    final currentPage = _pageController.page?.round();
    if (currentPage == provider.currentIndex) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageController.hasClients) return;
      _pageController.jumpToPage(provider.currentIndex);
    });
  }

  Future<void> _showWordSheet(
    BuildContext context,
    SentenceTokenData token,
  ) async {
    final provider = context.read<ReaderProvider>();
    final lookup = await provider.lookupWord(token);
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder:
          (ctx) => WordBottomSheet(
            lookupResult: lookup,
            onStatusSelected: (status) async {
              final word = lookup.word;
              if (word == null) return;
              await provider.updateWordStatus(word, status);
            },
          ),
    );
  }
}

class _SentenceTaskColumn extends StatelessWidget {
  const _SentenceTaskColumn({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      children:
          tasks
              .map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Card(
                      elevation: 3,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if ((task.title ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  task.title!,
                                  textAlign: TextAlign.center,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            Text(
                              task.promptTemplate,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if ((task.description ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  task.description!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }
}
