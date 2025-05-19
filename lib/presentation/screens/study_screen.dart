// lib/presentation/screens/study_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../domain/entities/audio_link.dart';
import '../../services/learning_service.dart';
import '../providers/study_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/buttons.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});
  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late StudyProvider _study;
  late SettingsProvider _settings;
  late AudioPlayer _audioPlayer;

  // Sentece & audio state (copied from your old code)
  List<AudioLink> _audioLinks = [];
  bool _audioLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  final int _initialLimit = 3;
  List<dynamic> _sentences = []; // your existing Sentence type
  int _sentenceIndex = 0;
  bool _batchLoaded   = false;
  bool _initialLoaded = false;

  @override
  void initState() {
    super.initState();
    _study = context.read<StudyProvider>();
    _settings = context.read<SettingsProvider>();
    _audioPlayer = AudioPlayer();

    // Listen to audio events
    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() => _isPlaying = false);
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
    setState(() {
      _batchLoaded   = true;
      _initialLoaded = false;
      _sentences     = [];
      _sentenceIndex = 0;
      _audioLinks    = [];
      _audioLoading  = false;
      _duration      = Duration.zero;
      _position      = Duration.zero;
      _isPlaying     = false;
    });
    await _loadExamplesForCurrent();
  }

  Future<void> _loadExamplesForCurrent() async {
    final batch = _study.batch;
    if (batch.isEmpty) return;

    final wordText = batch.first.text;

    // Phase 1: initial examples
    final initial = await context
        .read<LearningService>()
        .getInitialSentencesForWord(wordText, limit: _initialLimit);
    setState(() {
      _sentences     = initial;
      _sentenceIndex = 0;
      _initialLoaded = true;
    });

    // Fetch audio for the very first sentence
    await _loadAudioForSentence(initial[0].id);

    // Phase 2: remaining examples
    final rest = await context
        .read<LearningService>()
        .getRemainingSentencesForWord(
      wordText,
      initial.map((s) => s.id).toList(),
    );
    setState(() => _sentences.addAll(rest));
  }

  Future<void> _loadAudioForSentence(String sentenceId) async {
    setState(() {
      _audioLoading = true;
      _audioLinks   = [];
      _duration     = Duration.zero;
      _position     = Duration.zero;
      _isPlaying    = false;
    });
    final links = await context
        .read<LearningService>()
        .getAudioForSentence(sentenceId);
    setState(() {
      _audioLinks   = links;
      _audioLoading = false;
    });
  }

  Future<void> _togglePlay(String audioId) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      final url = 'https://tatoeba.org/audio/download/$audioId';
      await _audioPlayer.play(UrlSource(url));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _markResult(bool success) async {
    final initialTarget = _settings.dailyCount;
    await _study.markWord(success);
    await context.read<SettingsProvider>().incrementStudiedCount();

    final studied = context.read<SettingsProvider>().studiedCount;
    if (studied >= initialTarget) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Done!'),
          content: Text('You’ve completed $initialTarget words today 🎉'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // next batch
    setState(() {
      _initialLoaded = false;
      _sentences     = [];
      _sentenceIndex = 0;
      _audioLinks    = [];
      _audioLoading  = false;
      _duration      = Duration.zero;
      _position      = Duration.zero;
      _isPlaying     = false;
    });
    await _loadExamplesForCurrent();
  }

  Future<void> _skipCurrent() async {
    await _study.skipWord();
    // immediately load examples for the next word
    await _loadExamplesForCurrent();
  }

  void _nextSentence() {
    if (_sentences.isEmpty) return;
    setState(() {
      _sentenceIndex = (_sentenceIndex + 1) % _sentences.length;
    });
    _loadAudioForSentence(_sentences[_sentenceIndex].id);
  }

  void _prevSentence() {
    if (_sentences.isEmpty) return;
    setState(() {
      _sentenceIndex =
          (_sentenceIndex - 1 + _sentences.length) % _sentences.length;
    });
    _loadAudioForSentence(_sentences[_sentenceIndex].id);
  }

  @override
  Widget build(BuildContext context) {
    final batch = _study.batch;
    final initialTarget = _settings.dailyCount;
    final doneCount = initialTarget - batch.length;
    final currentPosition = doneCount + 1;

    if (!_batchLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (batch.isEmpty) {
      return const Scaffold(body: Center(child: Text('No words to study.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Study ($currentPosition/$initialTarget)'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fixed-size word card
            Expanded(
              flex: 6,
              child: Center(
                child: FractionallySizedBox(
                  heightFactor: 0.6,
                  widthFactor: 0.95,
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: !_initialLoaded
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                        children: [
                          SelectableText(
                            batch.first.text,
                            style:
                            Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: _sentences.isEmpty
                                ? const Center(child: Text('No example sentences.'))
                                : SingleChildScrollView(
                              child: Column(
                                children: [
                                  SelectableText(
                                    _sentences[_sentenceIndex].spanish,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  SelectableText(
                                    _sentences[_sentenceIndex].english,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey[700]),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Pinned audio section
            if (_audioLoading)
              const SizedBox(height: 48, child: Center(child: CircularProgressIndicator()))
            else if (_audioLinks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: () => _togglePlay(_audioLinks.first.audioId),
                        ),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _duration.inMilliseconds > 0
                                ? _position.inMilliseconds / _duration.inMilliseconds
                                : 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recorded by ${_audioLinks.first.username}.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_audioLinks.first.license.isNotEmpty)
                      Text(
                        'License: ${_audioLinks.first.license}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              )
            else
              const SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    'No audio available.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ),
          ],
        ),
      ),

      // Prev/Next + Mark buttons
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _sentences.isNotEmpty ? _prevSentence : null,
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _sentences.isNotEmpty
                            ? '${_sentenceIndex + 1} / ${_sentences.length}'
                            : '0 / 0',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _sentences.isNotEmpty ? _nextSentence : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: 'Got it',
                onPressed: () => _markResult(true),
              ),
              const SizedBox(height: 8),
              // Skip → drop word and fetch next
              SecondaryButton(
                label: 'Skip word',
                onPressed: _skipCurrent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
