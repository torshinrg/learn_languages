// lib/presentation/screens/review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../domain/entities/audio_link.dart';
import '../../services/learning_service.dart';
import '../providers/review_provider.dart';

/// Combines position & duration into one object.
class PositionData {
  final Duration position;
  final Duration duration;
  PositionData(this.position, this.duration);
}

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final ReviewProvider _review;
  late final AudioPlayer _player;
  late final Stream<PositionData> _positionDataStream;

  List<AudioLink> _links = [];
  bool _loadingAudio = false;

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

  Future<void> _initAudio() async {
    // Configure audio session for mobile focus
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());

    _player = AudioPlayer();
    // Combine position & duration streams
    _positionDataStream = Rx.combineLatest2<Duration, Duration?, PositionData>(
      _player.positionStream,
      _player.durationStream,
          (position, duration) =>
          PositionData(position, duration ?? Duration.zero),
    );
  }

  Future<void> _loadWordsAndAudio() async {
    await _review.loadDueWords();
    final s = _review.currentSentence;
    if (s != null) await _loadAudioForSentence(s.id);
  }

  Future<void> _loadAudioForSentence(String sentenceId) async {
    setState(() {
      _loadingAudio = true;
      _links = [];
    });

    final links = await context
        .read<LearningService>()
        .getAudioForSentence(sentenceId);

    setState(() {
      _links = links;
    });

    if (links.isNotEmpty) {
      final url =
          'https://tatoeba.org/audio/download/${links.first.audioId}';
      // Load new source & reset play state
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.pause();
    }

    setState(() {
      _loadingAudio = false;
    });
  }

  void _togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    setState(() {}); // update icon
  }

  @override
  void dispose() {
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
          final word     = review.currentWord!;
          final sentence = review.initialLoaded ? review.currentSentence! : null;

          return SafeArea(
            child: Column(
              children: [
                // Progress
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Word ${review.wordIndex + 1} of ${review.dueWords.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                // Fixed-size flashcard
                Expanded(
                  child: Center(
                    child: FractionallySizedBox(
                      heightFactor: 0.6,
                      widthFactor: 0.95,
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: sentence == null
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                            children: [
                              Text(
                                word.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      Text(
                                        sentence.spanish,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                            fontWeight:
                                            FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        sentence.english,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .copyWith(
                                          fontStyle:
                                          FontStyle.italic,
                                          color: Colors.grey[700],
                                        ),
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

                // Audio player section
                if (_loadingAudio)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  )
                else if (_links.isNotEmpty)
                  StreamBuilder<PositionData>(
                    stream: _positionDataStream,
                    builder: (_, snap) {
                      final pos = snap.data?.position ?? Duration.zero;
                      final dur = snap.data?.duration ?? Duration.zero;
                      final percent =
                      dur.inMilliseconds > 0
                          ? pos.inMilliseconds / dur.inMilliseconds
                          : 0.0;
                      return Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(_player.playing
                                    ? Icons.pause
                                    : Icons.play_arrow),
                                onPressed: _togglePlayPause,
                              ),
                              Expanded(
                                child: LinearProgressIndicator(value: percent),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${pos.inSeconds.toString().padLeft(2, '0')}/'
                                    '${dur.inSeconds.toString().padLeft(2, '0')}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Recorded by ${_links.first.username}.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (_links.first.license.isNotEmpty)
                            Text(
                              'License: ${_links.first.license}.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (_links.first.link.isNotEmpty)
                            GestureDetector(
                              onTap: () => launchUrlString(_links.first.link),
                              child: Text(
                                'Attribution',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                    decoration:
                                    TextDecoration.underline),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No audio available.',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  ),

                // Sentence nav
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () {
                          review.prevSentence();
                          final nxt = review.currentSentence;
                          if (nxt != null) _loadAudioForSentence(nxt.id);
                        },
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            review.initialLoaded
                                ? '${review.sentenceIndex + 1} / '
                                '${review.sentences.length}'
                                : '0 / 0',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          review.nextSentence();
                          final nxt = review.currentSentence;
                          if (nxt != null) _loadAudioForSentence(nxt.id);
                        },
                      ),
                    ],
                  ),
                ),

                // Quality buttons with spacing
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
