/// lib/presentation/screens/study_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../domain/entities/audio_link.dart';
import '../../domain/entities/sentence.dart';
import '../../services/learning_service.dart';
import '../providers/study_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/buttons.dart';
import '../widgets/interactive_word_sentence_card.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late final StudyProvider _study;
  late final SettingsProvider _settings;
  late final LearningService _learningService;
  late final AudioPlayer _audioPlayer;

  List<AudioLink> _audioLinks = [];
  bool _audioLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  final int _initialLimit = 3;
  List<Sentence> _sentences = [];
  int _sentenceIndex = 0;
  bool _batchLoaded = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _study = context.read<StudyProvider>();
    _settings = context.read<SettingsProvider>();
    _learningService = context.read<LearningService>();
    _audioPlayer = AudioPlayer();

    // LISTENERS WITH MOUNTED CHECKS
    _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) async {
      if (!mounted) return;
      setState(() => _isPlaying = false);
      // no-op beyond stopping
    });

    _loadBatch();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadBatch() async {
    await _study.loadBatch(_settings.dailyCount);
    if (!mounted) return;
    setState(() {
      _batchLoaded = true;
      _initialLoaded = false;
      _sentences = [];
      _sentenceIndex = 0;
      _audioLinks = [];
      _audioLoading = false;
      _duration = Duration.zero;
      _position = Duration.zero;
      _isPlaying = false;
    });
    await _loadExamplesForCurrent();
  }

  Future<void> _loadExamplesForCurrent() async {
    final batch = _study.batch;
    if (batch.isEmpty) return;
    final langCode =
        context.read<SettingsProvider>().learningLanguageCodes.first;

    // 1) load initial few examples:
    final initial = await _learningService.getInitialSentencesForWord(
      batch.first.text,
      langCode,
      limit: _initialLimit,
    );

    if (!mounted) return;
    setState(() {
      _sentences = initial;
      _sentenceIndex = 0;
      _initialLoaded = true;
    });

    if (initial.isNotEmpty) {
      await _loadAudioForSentence(initial[0].id(langCode), langCode);
    }

    // 2) fetch “the rest”
    final excludeIds = initial.map((s) => s.id(langCode)).toList();
    final rest = await _learningService.getRemainingSentencesForWord(
      batch.first.text,
      excludeIds,
      langCode,
    );

    if (!mounted) return;
    setState(() => _sentences.addAll(rest));
  }

  Future<void> _loadAudioForSentence(
    String sentenceId,
    String languageCode,
  ) async {
    if (!mounted) return;
    setState(() {
      _audioLoading = true;
      _audioLinks = [];
      _duration = Duration.zero;
      _position = Duration.zero;
      _isPlaying = false;
    });

    final links = await _learningService.getAudioForSentence(
      sentenceId,
      languageCode,
    );

    if (!mounted) return;
    setState(() {
      _audioLinks = links;
      _audioLoading = false;
    });
  }

  Future<void> _togglePlay(String audioId) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      if (!mounted) return;
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(
        UrlSource('https://tatoeba.org/audio/download/$audioId'),
      );
      if (!mounted) return;
      setState(() => _isPlaying = true);
    }
  }

  _markAsKnown() async {
    final batch = _study.batch;
    if (batch.isEmpty) return;

    // 1) Schedule this word as fully mastered (so it never appears again)
    final word = batch.first;
    await _learningService.markAsKnown(word.id);

    // 2) Remove it from today’s batch
    await _study.skipWord();

    // 3) If current batch is now empty, try to load the next “fresh” batch:
    if (_study.batch.isEmpty) {
      await _study.loadBatch(_settings.dailyCount);
    }

    // 4) If there really are no more words left at all, pop:
    if (_study.batch.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    // 5) Otherwise, load sentences for the new current word:
    await _loadExamplesForCurrent();
  }

  Future<void> _markResult(bool success) async {
    final target = _settings.dailyCount;
    await _study.markWord(success);
    await context.read<SettingsProvider>().incrementStudiedCount();

    if (!mounted) return;
    if (context.read<SettingsProvider>().studiedCount >= target) {
      await showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Done!'),
              content: Text('You’ve completed $target words today 🎉'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    // Load next examples
    await _loadExamplesForCurrent();
  }

  void _nextSentence() {
    if (_sentences.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _sentenceIndex = (_sentenceIndex + 1) % _sentences.length;
    });
    final langCode =
        context.read<SettingsProvider>().learningLanguageCodes.first;
    _loadAudioForSentence(
      _sentences[_sentenceIndex].id(langCode),
      langCode,
    );
  }

  void _prevSentence() {
    if (_sentences.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _sentenceIndex =
          (_sentenceIndex - 1 + _sentences.length) % _sentences.length;
    });
    final langCode =
        context.read<SettingsProvider>().learningLanguageCodes.first;
    _loadAudioForSentence(
      _sentences[_sentenceIndex].id(langCode),
      langCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final batch = _study.batch;
    final loc = AppLocalizations.of(context)!;

    if (!_batchLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (batch.isEmpty) {
      return Scaffold(body: Center(child: Text(loc.no_words)));
    }

    final learnedSoFar = _settings.studiedCount;
    final totalTarget = _settings.dailyCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('${loc.study} (${learnedSoFar + 1}/$totalTarget)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveWordSentenceCard(
                wordText: batch.first.text,
                sentences: _sentences,
                sentenceIndex: _sentenceIndex,
                audioLinks: _audioLinks,
                audioLoading: _audioLoading,
                isPlaying: _isPlaying,
                position: _position,
                duration: _duration,
                onToggleAudio: () {
                  if (_audioLinks.isNotEmpty) {
                    _togglePlay(_audioLinks.first.audioId);
                  }
                },
                onReplayAudio: () {
                  if (_audioLinks.isNotEmpty) {
                    _togglePlay(_audioLinks.first.audioId);
                  }
                },
                onPrevSentence: _prevSentence,
                onNextSentence: _nextSentence,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PrimaryButton(
                label: loc.got_it,
                onPressed: () => _markResult(true),
              ),
              const SizedBox(height: 8),
              SecondaryButton(label: 'Mark as Known', onPressed: _markAsKnown),
            ],
          ),
        ),
      ),
    );
  }
}
