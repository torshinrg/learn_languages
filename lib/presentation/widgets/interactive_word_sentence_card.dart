// lib/presentation/widgets/interactive_word_sentence_card.dart

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../domain/entities/audio_link.dart';
import '../../domain/entities/sentence.dart';
import '../../services/audio_check_service.dart';

import '../../services/pronunciation_scoring_service.dart';

class InteractiveWordSentenceCard extends StatefulWidget {
  final String wordText;
  final List<Sentence> sentences;
  final int sentenceIndex;

  final bool audioLoading;
  final List<AudioLink> audioLinks;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  final VoidCallback onToggleAudio;
  final VoidCallback onReplayAudio;
  final VoidCallback onPrevSentence;
  final VoidCallback onNextSentence;

  const InteractiveWordSentenceCard({
    Key? key,
    required this.wordText,
    required this.sentences,
    required this.sentenceIndex,
    required this.audioLoading,
    required this.audioLinks,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onToggleAudio,
    required this.onReplayAudio,
    required this.onPrevSentence,
    required this.onNextSentence,
  }) : super(key: key);

  @override
  State<InteractiveWordSentenceCard> createState() =>
      _InteractiveWordSentenceCardState();
}

class _InteractiveWordSentenceCardState
    extends State<InteractiveWordSentenceCard> {
  final _recorder = AudioRecorder();
  late final AudioCheckService _checker;

  StreamSubscription<Amplitude>? _ampSub;
  bool _recording = false;
  bool _processing = false;
  double? _score;
  double _currentAmp = 0.0;
  DateTime _lastVoice = DateTime.now();

  bool _hasAutoPlayed = false;
  String? _transcript; // Holds the latest STT result

  static const _startThresholdDb = -20.0;
  static const _silenceTimeout = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _checker = GetIt.instance<AudioCheckService>();
    _checker.init();
  }

  @override
  void didUpdateWidget(covariant InteractiveWordSentenceCard old) {
    super.didUpdateWidget(old);

    // Reset when the sentence changes:
    if (widget.sentenceIndex != old.sentenceIndex) {
      _hasAutoPlayed = false;
      _ampSub?.cancel();
      setState(() {
        _recording = false;
        _processing = false;
        _score = null;
        _transcript = null;
      });
    }

    // Auto-play exactly once:
    if (!_hasAutoPlayed &&
        !_recording &&
        !_processing &&
        !widget.audioLoading &&
        widget.audioLinks.isNotEmpty) {
      _hasAutoPlayed = true;
      widget.onToggleAudio();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Microphone denied')));
      return;
    }

    final dir = await getTemporaryDirectory();
    final sid = widget.sentences[widget.sentenceIndex].id;
    final path = '${dir.path}/user_$sid.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path,
    );
    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(_handleAmp);

    setState(() {
      _recording = true;
      _processing = false;
      _score = null;
      _transcript = null;
      _lastVoice = DateTime.now();
    });
  }

  void _handleAmp(Amplitude amp) {
    final now = DateTime.now();
    final db = amp.current;
    final lin = pow(10, db / 20).clamp(0.0, 1.0).toDouble();
    final since = now.difference(_lastVoice);

    if (db > _startThresholdDb) {
      _lastVoice = now;
    } else if (_recording && since > _silenceTimeout) {
      _stopAndScore();
    }

    setState(() => _currentAmp = lin);
  }

  Future<void> _stopAndScore() async {
    await _ampSub?.cancel();
    final userPath = await _recorder.stop();
    setState(() {
      _processing = true;
      _recording = false;
    });

    if (userPath == null || widget.audioLinks.isEmpty) {
      setState(() => _processing = false);
      return;
    }

    // build a full URL from the audioId
    final audioLink = widget.audioLinks.first;
    final refUrl = 'https://tatoeba.org/audio/download/${audioLink.audioId}';
    final current = widget.sentences[widget.sentenceIndex];
    final result = await _checker.compare(
      userAudioPath: userPath,
      expectedText: current.spanish, // or your expected sentence text
      lang: 'es',
    );

    setState(() {
      _processing = false;
      _score = result.score;
      _transcript = result.userText;
    });
  }

  /// Remove Spanish accents so “sé” → “se”, “ñ” → “n”, etc.
  String _removeDiacritics(String s) {
    const withDia = 'áÁéÉíÍóÓúÚüÜñÑ';
    const withoutDia = 'aAeEiIoOuUuUnN';
    for (var i = 0; i < withDia.length; i++) {
      s = s.replaceAll(withDia[i], withoutDia[i]);
    }
    return s;
  }

  Widget _buildColorizedSentence(TextTheme theme, String expectedSentence) {
    final scorer = PronunciationScoringService();

    // 1) Normalize expected words
    final expected =
        expectedSentence
            .replaceAll(RegExp(r'[.,!?;:]'), '')
            .split(RegExp(r'\s+'))
            .map((w) => _removeDiacritics(w).toLowerCase())
            .toList();

    // 2) Normalize actual transcript words
    final actual =
        (_transcript ?? '')
            .replaceAll(RegExp(r'[.,!?;:]'), '')
            .split(RegExp(r'\s+'))
            .map((w) => _removeDiacritics(w).toLowerCase())
            .toList();

    // 3) Build colored spans
    final spans = <TextSpan>[];
    for (var i = 0; i < expected.length; i++) {
      final e = expected[i];
      double similarity = 0.0;

      if (i < actual.length) {
        similarity = scorer.score(e, actual[i]);
      }

      final match = similarity >= 0.8;

      // display the original expected word (with accents)
      final displayWord =
          expectedSentence
              .replaceAll(RegExp(r'[.,!?;:]'), '')
              .split(RegExp(r'\s+'))[i];

      spans.add(
        TextSpan(
          text: '$displayWord ',
          style: theme.titleMedium!.copyWith(
            fontWeight: FontWeight.bold,
            color: match ? Colors.green : Colors.red,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final hasSentence =
        widget.sentences.isNotEmpty &&
        widget.sentenceIndex < widget.sentences.length;
    final current = hasSentence ? widget.sentences[widget.sentenceIndex] : null;

    final navRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onPrevSentence,
          ),
          Expanded(
            child: Center(
              child: Text(
                widget.sentences.isNotEmpty
                    ? '${widget.sentenceIndex + 1} / ${widget.sentences.length}'
                    : '0 / 0',
                style: theme.bodySmall,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: widget.onNextSentence,
          ),
        ],
      ),
    );

    final body = SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80), // give room for navRow
      child: Column(
        children: [
          // Word + Sentence + icon
          SizedBox(
            width: 350,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Word
                    SelectableText(
                      widget.wordText,
                      style: theme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Tappable sentence + icon, or colorized result
                    InkWell(
                      onTap: hasSentence ? widget.onReplayAudio : null,
                      child:
                          widget.audioLoading
                              // still loading audio
                              ? const Center(child: CircularProgressIndicator())
                              : (!hasSentence
                                  // no sentence yet
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : (_transcript != null
                                      // show colorized
                                      ? _buildColorizedSentence(
                                        theme,
                                        current!.spanish,
                                      )
                                      // normal tappable row
                                      : Row(
                                        children: [
                                          Icon(
                                            Icons.volume_up,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: SelectableText(
                                              current!.spanish,
                                              style: theme.titleMedium!
                                                  .copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ))),
                    ),
                    widget.audioLoading
                        // still loading audio
                        ? const Center(child: null)
                        : Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                current!.english,
                                style: theme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Recording & feedback (unchanged)...
          if (_processing)
            const CircularProgressIndicator()
          else if (_recording)
            GestureDetector(
              onTap: _stopAndScore,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: 60 + (_currentAmp * 40),
                height: 60 + (_currentAmp * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(0.3 + _currentAmp * 0.7),
                ),
              ),
            )
          else if (_score != null) ...[
            Text(
              _score! >= 0.9
                  ? '🎉 Excellent! You nailed it!'
                  : _score! >= 0.75
                  ? '👍 Great job!'
                  : _score! >= 0.6
                  ? '🙂 Good work, keep going!'
                  : '💪 Don’t give up, try again!',
              style: theme.headlineMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_score! < 0.6)
              OutlinedButton.icon(
                icon: const Icon(Icons.mic),
                label: const Text('Tap to Speak Again'),
                onPressed: _startRecording,
              )
            else
              ElevatedButton(
                onPressed: widget.onNextSentence,
                child: const Text('Next Sentence'),
              ),
          ] else
            OutlinedButton.icon(
              icon: const Icon(Icons.mic),
              label: const Text('Tap to Speak'),
              onPressed: _startRecording,
            ),

          if (widget.audioLinks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Recorded by ${widget.audioLinks.first.username}.',
              style: theme.bodySmall,
            ),
            if (widget.audioLinks.first.license.isNotEmpty)
              Text(
                'License: ${widget.audioLinks.first.license}.',
                style: theme.bodySmall,
              ),
          ],
        ],
      ),
    );

    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Stack(
        children: [
          // main content
          Positioned.fill(child: body),

          // nav pinned to bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: navRow,
            ),
          ),
        ],
      ),
    );
  }
}
