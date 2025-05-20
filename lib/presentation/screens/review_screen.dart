// File: lib/presentation/screens/review_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/audio_link.dart';
import '../../domain/entities/sentence.dart';
import '../../services/learning_service.dart';
import '../providers/review_provider.dart';
import '../widgets/word_sentence_card.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewProvider _review;
  late final AudioPlayer _player;

  List<AudioLink> _links = [];
  bool _loadingAudio = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  late final StreamSubscription<Duration> _posSub;
  late final StreamSubscription<Duration?> _durSub;
  late final StreamSubscription<PlayerState> _stateSub;

  final Map<String, int> _qualityMap = {
    'Again': 0,
    'Hard': 3,
    'Good': 4,
    'Easy': 5,
  };
  final List<String> _qualityLabels = ['Again', 'Hard', 'Good', 'Easy'];

  @override
  void initState() {
    super.initState();
    _review = context.read<ReviewProvider>();
    _initAudio();
    _loadWordsAndAudio();
  }

  void _initAudio() {
    _player = AudioPlayer();

    // Listen and guard every setState behind mounted
    _posSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _durSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
    _stateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _loadWordsAndAudio() async {
    await _review.loadDueWords();
    final s = _review.currentSentence;
    if (s != null) await _loadAudioForSentence(s.id);
  }

  Future<void> _loadAudioForSentence(String sentenceId) async {
    if (!mounted) return;
    setState(() {
      _loadingAudio = true;
      _links = [];
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
    });

    final links = await context
        .read<LearningService>()
        .getAudioForSentence(sentenceId);

    if (!mounted) return;
    setState(() {
      _links = links;
      _loadingAudio = false;
    });

    if (links.isNotEmpty) {
      final url = 'https://tatoeba.org/audio/download/${links.first.audioId}';
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.pause();
    }
  }

  Future<void> _togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  @override
  void dispose() {
    _posSub.cancel();
    _durSub.cancel();
    _stateSub.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: Consumer<ReviewProvider>(
        builder: (_, review, __) {
          if (review.dueWords.isEmpty) {
            return const Center(child: Text('No reviews due right now.'));
          }
          return SafeArea(
            child: Column(
              children: [
                // Progress indicator
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Word ${review.wordIndex + 1} of ${review.dueWords.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                // Shared card + audio + nav
                Expanded(
                  child: WordSentenceCard(
                    wordText: review.currentWord!.text,
                    sentences: review.sentences,
                    sentenceIndex: review.sentenceIndex,
                    audioLinks: _links,
                    audioLoading: _loadingAudio,
                    isPlaying: _isPlaying,
                    position: _position,
                    duration: _duration,
                    onToggleAudio: _togglePlayPause,
                    onPrevSentence: () {
                      review.prevSentence();
                      final nxt = review.currentSentence;
                      if (nxt != null) _loadAudioForSentence(nxt.id);
                    },
                    onNextSentence: () {
                      review.nextSentence();
                      final nxt = review.currentSentence;
                      if (nxt != null) _loadAudioForSentence(nxt.id);
                    },
                  ),
                ),

                // Quality buttons
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: _qualityLabels.map((label) {
                      return ElevatedButton(
                        onPressed: () async {
                          final q = _qualityMap[label]!;
                          await review.markWord(q);
                          final nxt = review.currentSentence;
                          if (nxt != null) _loadAudioForSentence(nxt.id);
                        },
                        child: Text(label),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
