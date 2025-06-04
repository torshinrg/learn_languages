/// lib/presentation/widgets/interactive_word_sentence_card.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:learn_languages/presentation/widgets/task_widget.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/audio_link.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/entities/task.dart';
import '../../services/audio_check_service.dart';
import '../../services/pronunciation_scoring_service.dart';
import '../providers/task_provider.dart';
import '../providers/settings_provider.dart';

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
  late final SpeechToText _stt;

  StreamSubscription<Amplitude>? _ampSub;
  bool _recording = false;
  bool _processing = false;
  double? _score;
  double _currentAmp = 0.0;

  String _sttTranscription = '';
  String _whisperTranscription = '';

  DateTime? _sttStart;
  DateTime? _sttEnd;
  DateTime? _whisperStart;
  DateTime? _whisperEnd;

  Task? _selectedSentenceTask;
  List<Task> _lastSeenSentenceTasks = [];
  int _lastSentenceIndex = -1;

  @override
  void initState() {
    super.initState();
    _checker = GetIt.instance<AudioCheckService>();
    _checker.init();
    _stt = SpeechToText();
    _initStt();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Whenever dependencies (e.g. TaskProvider) change, maybe pick a new random task:
    _maybePickRandomSentenceTask();
  }

  @override
  void didUpdateWidget(covariant InteractiveWordSentenceCard old) {
    super.didUpdateWidget(old);
    // If the sentence index changed, clear selection so we pick again:
    if (widget.sentenceIndex != old.sentenceIndex) {
      _lastSentenceIndex = widget.sentenceIndex;
      _selectedSentenceTask = null;
      _maybePickRandomSentenceTask();
    }
    // If TaskProvider reloaded (list length changed), pick again:
    _maybePickRandomSentenceTask();
  }

  void _maybePickRandomSentenceTask() {
    final provider = context.watch<TaskProvider>();
    final sentenceTasks =
        provider.sentenceTasks.where((t) => t.taskType == 'sentence').toList();

    // Re-pick if:
    // 1) number of tasks changed, or
    // 2) we have no selected task yet for this sentence, or
    // 3) sentence index changed
    if ((_lastSeenSentenceTasks.length != sentenceTasks.length) ||
        (_selectedSentenceTask == null && sentenceTasks.isNotEmpty) ||
        (_lastSentenceIndex != widget.sentenceIndex)) {
      _lastSeenSentenceTasks = sentenceTasks;
      _lastSentenceIndex = widget.sentenceIndex;

      if (sentenceTasks.isEmpty) {
        _selectedSentenceTask = null;
      } else {
        final randIndex = Random().nextInt(sentenceTasks.length);
        _selectedSentenceTask = sentenceTasks[randIndex];
      }
      setState(() {});
    }
  }

  Future<void> _initStt() async {
    await _stt.initialize();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    final dir = await getTemporaryDirectory();
    final langCode =
        context.read<SettingsProvider>().learningLanguageCodes.first;
    final sid = widget.sentences[widget.sentenceIndex].id(langCode);
    final path = '${dir.path}/user_$sid.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path,
    );

    _sttStart = DateTime.now();
    _stt.listen(
      onResult: (result) {
        if (!mounted) return;
        setState(() {
          _sttTranscription = result.recognizedWords;
        });
      },
    );

    _ampSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 100))
        .listen(_handleAmp);

    setState(() {
      _recording = true;
      _processing = false;
      _score = null;
      _currentAmp = 0.0;
    });
  }

  void _handleAmp(Amplitude amp) {
    final now = DateTime.now();
    final db = amp.current;
    final lin = pow(10, db / 20).clamp(0.0, 1.0).toDouble();

    if (db > -20.0) {
      _sttStart = now;
    } else {
      final since = now.difference(_sttStart!);
      if (_recording && since > const Duration(seconds: 2)) {
        _stopAndScore();
      }
    }
    if (!mounted) return;
    setState(() => _currentAmp = lin);
  }

  Future<void> _stopAndScore() async {
    _ampSub?.cancel();
    _stt.stop();
    _sttEnd = DateTime.now();

    final userPath = await _recorder.stop();
    setState(() {
      _processing = true;
      _recording = false;
    });
    if (userPath == null) {
      setState(() => _processing = false);
      return;
    }

    final langCode =
        context.read<SettingsProvider>().learningLanguageCodes.first;
    _whisperStart = DateTime.now();
    final result = await _checker.compare(
      userAudioPath: userPath,
      expectedText:
          widget.sentences[widget.sentenceIndex].text(langCode),
      lang: langCode,
    );
    _whisperEnd = DateTime.now();

    setState(() {
      _processing = false;
      _score = result.score;
      _whisperTranscription = result.userText;
    });
  }

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

    final expected =
        expectedSentence
            .replaceAll(RegExp(r'[.,!?;:]'), '')
            .split(RegExp(r'\s+'))
            .map((w) => _removeDiacritics(w).toLowerCase())
            .toList();

    final actual =
        (_whisperTranscription)
            .replaceAll(RegExp(r'[.,!?;:]'), '')
            .split(RegExp(r'\s+'))
            .map((w) => _removeDiacritics(w).toLowerCase())
            .toList();

    final spans = <TextSpan>[];
    for (var i = 0; i < expected.length; i++) {
      final e = expected[i];
      double similarity = 0.0;
      if (i < actual.length) {
        similarity = scorer.score(e, actual[i]);
      }
      final match = similarity >= 0.8;
      final displayWord = expectedSentence.split(RegExp(r'\s+'))[i];

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
    final loc = AppLocalizations.of(context)!;

    // Determine language codes (first = learning, second = translation, if provided)
    final codes = context.read<SettingsProvider>().learningLanguageCodes;
    final learnCode = codes.first;
    final translateCode = codes.length > 1 ? codes[1] : '';

    // We no longer randomly re-pick in build; instead we rely on _selectedSentenceTask:
    final sentenceTask = _selectedSentenceTask;

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
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          // ── Word + Sentence + icon row ───────────────────────────
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
                    // Word text
                    SelectableText(
                      widget.wordText,
                      style: theme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Either spinner, play row, or colorized result:
                    InkWell(
                      onTap: hasSentence ? widget.onReplayAudio : null,
                      child:
                          widget.audioLoading
                              ? const Center(child: CircularProgressIndicator())
                              : (!hasSentence
                                  ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                  : (_whisperTranscription.isNotEmpty
                                      ? _buildColorizedSentence(
                                        theme,
                                        current!.text(learnCode),
                                      )
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
                                              current!.text(learnCode),
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

                    // “Translation” (second language), if available:
                    widget.audioLoading
                        ? const SizedBox()
                        : (hasSentence && translateCode.isNotEmpty
                            ? Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    current!.text(translateCode),
                                    style: theme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                            : const SizedBox()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Recording / processing / feedback area ─────────────────
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
                  ? loc.excellent
                  : _score! >= 0.75
                  ? loc.great_job
                  : _score! >= 0.6
                  ? loc.good_work
                  : loc.try_again,
              style: theme.headlineMedium!.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'STT: "${_sttTranscription}" '
              '(${_sttEnd!.difference(_sttStart!).inMilliseconds} ms)',
              style: theme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Whisper: "${_whisperTranscription}" '
              '(${_whisperEnd!.difference(_whisperStart!).inMilliseconds} ms)',
              style: theme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (_score! < 0.6)
              OutlinedButton.icon(
                icon: const Icon(Icons.mic),
                label: Text(loc.tap_to_speak_again),
                onPressed: _startRecording,
              )
            else
              ElevatedButton(
                onPressed: widget.onNextSentence,
                child: Text(loc.next_sentence),
              ),
          ] else
            OutlinedButton.icon(
              icon: const Icon(Icons.mic),
              label: Text(loc.tap_to_speak),
              onPressed: _startRecording,
            ),

          // ── Show the one picked Task (no longer re-picking on every build) ──
          if (sentenceTask != null) ...[
            const SizedBox(height: 16),
            TaskWidget(task: sentenceTask),
          ] else ...[
            const SizedBox(height: 0),
          ],

          const SizedBox(height: 24),

          // ── Attribution (audio source) ────────────────────────────
          if (widget.audioLinks.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${loc.recorded_by} ${widget.audioLinks.first.username}.',
              style: theme.bodySmall,
            ),
            if (widget.audioLinks.first.license.isNotEmpty)
              Text(
                '${loc.licence} ${widget.audioLinks.first.license}.',
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
          Positioned.fill(child: body),
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
