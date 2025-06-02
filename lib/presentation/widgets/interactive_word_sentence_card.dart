// lib/presentation/widgets/interactive_word_sentence_card.dart

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

  bool _hasAutoPlayed = false;
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
    // Whenever dependencies change (e.g. the TaskProvider becomes available),
    // try to pick a random task if it wasn’t picked yet:
    _maybePickRandomSentenceTask();
  }

  @override
  void didUpdateWidget(covariant InteractiveWordSentenceCard old) {
    super.didUpdateWidget(old);

    // If the sentence index changes, we want to pick a new random Task for the new sentence:
    if (widget.sentenceIndex != old.sentenceIndex) {
      _lastSentenceIndex = widget.sentenceIndex;
      _selectedSentenceTask = null; // force a new pick
      _maybePickRandomSentenceTask();
    }

    // If your UI locale or provider changed and the underlying sentenceTasks list got reloaded,
    // we also want to re-pick from the new list. We'll detect that in `_maybePickRandomSentenceTask()`.
  }

  void _maybePickRandomSentenceTask() {
    final provider = context.watch<TaskProvider>();
    final sentenceTasks = provider.sentenceTasks.where((t) => t.taskType == 'sentence').toList();

    // If the list itself has changed length—or if we haven't yet chosen a task for this sentenceIndex—re-pick:
    if ((_lastSeenSentenceTasks.length != sentenceTasks.length) ||
        (_selectedSentenceTask == null && sentenceTasks.isNotEmpty) ||
        (_lastSentenceIndex != widget.sentenceIndex)) {
      _lastSeenSentenceTasks = sentenceTasks;
      _lastSentenceIndex = widget.sentenceIndex;

      if (sentenceTasks.isEmpty) {
        print('[InteractiveCard] no sentence‐task found for locale or list was empty');
        _selectedSentenceTask = null;
      } else {
        final randIndex = Random().nextInt(sentenceTasks.length);
        _selectedSentenceTask = sentenceTasks[randIndex];
        print(
            '[InteractiveCard] chosen Task for sentenceIndex=${widget.sentenceIndex} → '
                'id="${_selectedSentenceTask!.id}", '
                '“${_selectedSentenceTask!.description}”'
        );
      }
      // We want to rebuild now that _selectedSentenceTask has a new value (or null):
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

    // Prepare file path for recorded WAV
    final dir = await getTemporaryDirectory();
    final sid = widget.sentences[widget.sentenceIndex].id;
    final path = '${dir.path}/user_$sid.wav';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000),
      path: path,
    );

    // Start SpeechToText and record start time
    _sttStart = DateTime.now();
    _stt.listen(
      onResult: (result) {
        setState(() {
          _sttTranscription = result.recognizedWords;
        });
      },
    );

    // Start amplitude listener (to auto-stop on silence)
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

    // If db > threshold, reset silence timer
    if (db > -20.0) {
      _sttStart = now;
    } else {
      final since = now.difference(_sttStart!);
      if (_recording && since > const Duration(seconds: 2)) {
        // silence for >2 seconds → stop
        _stopAndScore();
      }
    }

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

    // Run Whisper over the recorded file
    _whisperStart = DateTime.now();
    final result = await _checker.compare(
      userAudioPath: userPath,
      expectedText: widget.sentences[widget.sentenceIndex].spanish,
      lang: 'es',
    );
    _whisperEnd = DateTime.now();

    setState(() {
      _processing = false;
      _score = result.score;
      _whisperTranscription = result.userText;
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

    // 2) Normalize actual transcript words (Whisper)
    final actual =
        (_whisperTranscription)
            .replaceAll(RegExp(r'[.,!?;:]'), '')
            .split(RegExp(r'\s+'))
            .map((w) => _removeDiacritics(w).toLowerCase())
            .toList();

    // 3) Build colored spans per word
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

    // 1) Print the UI locale
    final localeCode = Localizations.localeOf(context).languageCode;
    print('[InteractiveCard] UI locale = $localeCode');

    // 2) Fetch all tasks of type "sentence" from the provider
    final sentenceTasks = context
        .watch<TaskProvider>()
        .sentenceTasks
        .where((t) => t.taskType == 'sentence')
        .toList();

    // 3) Print how many tasks we got for “sentence”
    print('[InteractiveCard] number of sentence‐tasks in provider = ${sentenceTasks.length}');

    // 4) Pick a random one (if non‐empty)
    Task? sentenceTask;
    if (sentenceTasks.isNotEmpty) {
      final randIndex = Random().nextInt(sentenceTasks.length);
      sentenceTask = sentenceTasks[randIndex];

      // 5) Print out the chosen task’s fields
      print('[InteractiveCard] chosen Task at index $randIndex: '
          'id="${sentenceTask.id}", description="${sentenceTask.description}", '
          'locale="${sentenceTask.locale}", type="${sentenceTask.taskType}"');
    } else {
      print('[InteractiveCard] no sentence‐task found for this locale');
      sentenceTask = null;
    }

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
          // Word + Sentence + icon row
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

                    // Either a loading spinner, a tappable “play” row, or colorized result
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
                                        current!.spanish,
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

                    // Show English translation if sentence exists and not loading
                    widget.audioLoading
                        ? const SizedBox()
                        : (hasSentence
                            ? Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    current!.english,
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

          // Recording / processing / feedback area
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
          if (sentenceTask != null) ...[
            const SizedBox(height: 16),
            TaskWidget(task: sentenceTask),
          ] else ...[
            // We can show a placeholder or just no widget
            const SizedBox(height: 0),
          ],

          const SizedBox(height: 24),



          // Attribution text (recording license/username)
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
