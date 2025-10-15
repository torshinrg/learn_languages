import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:learn_languages/domain/entities/sentence.dart';
import 'package:learn_languages/domain/entities/word.dart';

class InteractiveWordSentenceCard extends StatefulWidget {
  final Word word;
  final List<Sentence> sentences; // full pool for the word
  final Map<String, Sentence> translationsByGroup; // groupId -> translation
  final int batchSize;

  // Decisions
  final VoidCallback onNextWord; // advance to next word
  final VoidCallback onMarkKnown; // mark word as known

  const InteractiveWordSentenceCard({
    super.key,
    required this.word,
    required this.sentences,
    required this.translationsByGroup,
    this.batchSize = 3,
    required this.onNextWord,
    required this.onMarkKnown,
  });

  @override
  State<InteractiveWordSentenceCard> createState() => _InteractiveWordSentenceCardState();
}

class _InteractiveWordSentenceCardState extends State<InteractiveWordSentenceCard> {
  late final AudioPlayer _player;
  late final PageController _pageController;
  late List<Sentence> _pool;
  final Set<String> _servedIds = {};
  final Set<String> _exposedThisBatch = {};
  List<Sentence> _currentBatch = [];
  int _batchesServed = 0;
  int _activePage = 0;
  Timer? _dwellTimer;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _pageController = PageController();
    _pool = List.of(widget.sentences);
    _startNewBatch();
  }

  @override
  void didUpdateWidget(covariant InteractiveWordSentenceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.word.id != widget.word.id) {
      _pool = List.of(widget.sentences);
      _servedIds.clear();
      _batchesServed = 0;
      _startNewBatch();
    } else if (oldWidget.sentences != widget.sentences) {
      _pool = List.of(widget.sentences);
      // keep served set; refresh batch if needed
      if (_currentBatch.isEmpty) {
        _startNewBatch();
      }
    }
  }

  void _startNewBatch() {
    _exposedThisBatch.clear();
    _currentBatch = _computeNextBatch();
    _activePage = 0;
    _restartDwellTimerForActive();
    _autoPlayActive();
    setState(() {});
    // After rebuild, snap to first page of new batch if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  List<Sentence> _computeNextBatch() {
    final remaining = _pool.where((s) => !_servedIds.contains(s.id)).toList();
    if (remaining.isEmpty) return [];
    remaining.sort((a, b) => a.content.length.compareTo(b.content.length));
    final take = remaining.take(widget.batchSize).toList();
    _servedIds.addAll(take.map((e) => e.id));
    _batchesServed += 1;
    return take;
  }

  int get _exposureTarget => _currentBatch.isEmpty ? 0 : _currentBatch.length;
  bool get _batchComplete => _exposedThisBatch.length >= _exposureTarget && _exposureTarget > 0;

  Future<void> _playFor(Sentence s) async {
    final url = _resolveAudioUrl(s);
    print('[Card] Play requested for sentence id=' + s.id + ' lang=' + s.languageId + ' group=' + s.groupId + ' audioRaw=' + (s.audioUrl ?? 'null'));
    print('[Card] Resolved audio URL: ' + (url ?? 'null'));
    if (url == null) return;
    try {
      await _player.stop();
      await _player.setUrl(url);
      // slight delay can improve reliability on rapid page changes
      await Future.delayed(const Duration(milliseconds: 50));
      await _player.play(); // completes on finished
      _countExposure(s);
    } catch (e) {
      print('[Card] Audio playback error for sentence=' + s.id + ': ' + e.toString());
    }
  }

  String? _resolveAudioUrl(Sentence s) {
    final raw = s.audioUrl;
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = dotenv.env['TATOEBA_DOWNLOAD_BASE'] ?? 'https://tatoeba.org/audio/download';
    return '$base/$raw';
  }

  void _countExposure(Sentence s) {
    if (_exposedThisBatch.contains(s.id)) return;
    _exposedThisBatch.add(s.id);
    setState(() {});
  }

  void _restartDwellTimerForActive() {
    _dwellTimer?.cancel();
    if (_batchComplete) return;
    if (_activePage < 0 || _activePage >= _currentBatch.length) return;
    final s = _currentBatch[_activePage];
    _dwellTimer = Timer(const Duration(milliseconds: 2000), () {
      _countExposure(s);
    });
  }

  void _autoPlayActive() {
    if (_activePage < 0 || _activePage >= _currentBatch.length) return;
    final s = _currentBatch[_activePage];
    final url = _resolveAudioUrl(s);
    print('[Card] Active page index=' + _activePage.toString() + ' sentenceId=' + s.id + ' audioRaw=' + (s.audioUrl ?? 'null') + ' resolved=' + (url ?? 'null'));
    _playFor(s);
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _player.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = _pool.where((s) => !_servedIds.contains(s.id)).length;
    final int contentPages = _currentBatch.length + (_batchComplete ? 1 : 0); // +1 for End Card when complete
    final int pagesCount = contentPages + (_batchComplete ? 1 : 0); // +1 sentinel to allow scrolling to next batch
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.word.text, style: theme.textTheme.headlineSmall)),
                _ProgressChip(
                  done: _exposedThisBatch.length.clamp(0, widget.batchSize),
                  total: widget.batchSize,
                ),
                Builder(builder: (context) {
                  // Determine current sentence (if any)
                  Sentence? s;
                  if (_activePage >= 0 && _activePage < _currentBatch.length) {
                    s = _currentBatch[_activePage];
                  }
                  final hasAudio = s != null && s.audioUrl != null && s.audioUrl!.isNotEmpty && _resolveAudioUrl(s) != null;
                  return IconButton(
                    tooltip: hasAudio ? 'Play audio' : 'No audio',
                    icon: Icon(hasAudio ? Icons.volume_up : Icons.volume_off),
                    onPressed: hasAudio && s != null ? () => _playFor(s!) : null,
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: pagesCount,
                onPageChanged: (i) {
                  _activePage = i;
                  _restartDwellTimerForActive();
                  _autoPlayActive();
                },
                itemBuilder: (ctx, i) {
                  // Sentinel page to trigger next batch by scrolling beyond End Card
                  if (_batchComplete && i == pagesCount - 1) {
                    // Queue next batch and show a tiny loader placeholder
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _startNewBatch();
                    });
                    return const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  // End Card is last content page when batch is complete
                  if (_batchComplete && i == contentPages - 1) {
                    // End Card page
                    return _EndCard(
                      word: widget.word.text,
                      canContinue: remaining > 0,
                      onNextWord: widget.onNextWord,
                      onContinue: () {
                        _startNewBatch();
                      },
                      onMarkKnown: widget.onMarkKnown,
                      seenCount: _exposedThisBatch.length.clamp(0, widget.batchSize),
                      total: widget.batchSize,
                    );
                  }
                  final s = _currentBatch[i];
                  final t = s.groupId.isNotEmpty ? widget.translationsByGroup[s.groupId] : null;
                  // Debug print of full sentence info and translation
                  print('[Card] Build page i=' + i.toString() +
                      ' id=' + s.id +
                      ' lang=' + s.languageId +
                      ' group=' + s.groupId +
                      ' audioRaw=' + (s.audioUrl ?? 'null') +
                      ' content="' + s.content + '"' +
                      ' translationGroup=' + (t?.groupId ?? '') +
                      ' translation="' + (t?.content ?? '') + '"');
                  return _SentencePage(
                    sentence: s,
                    translation: t,
                    onPlay: () => _playFor(s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentencePage extends StatelessWidget {
  final Sentence sentence;
  final Sentence? translation;
  final VoidCallback onPlay;

  const _SentencePage({
    required this.sentence,
    required this.translation,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPlay,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sentence.content, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            if (translation != null) ...[
              const SizedBox(height: 4),
              Text(
                translation!.content,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressChip extends StatelessWidget {
  final int done;
  final int total;
  const _ProgressChip({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$done/$total'),
    );
  }
}

class _EndCard extends StatelessWidget {
  final String word;
  final bool canContinue;
  final VoidCallback onContinue;
  final VoidCallback onMarkKnown;
  final VoidCallback onNextWord;
  final int seenCount;
  final int total;

  const _EndCard({
    required this.word,
    required this.canContinue,
    required this.onContinue,
    required this.onMarkKnown,
    required this.onNextWord,
    required this.seenCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('You\'ve seen $seenCount example${seenCount == 1 ? '' : 's'} for "$word".', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Word $word • $seenCount/$total done', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: canContinue ? onContinue : null,
            child: const Text('Continue learning this word'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onMarkKnown,
            child: const Text('I know this word'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onNextWord,
            child: const Text('Next word'),
          ),
        ],
      ),
    );
  }
}
