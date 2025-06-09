/// lib/presentation/screens/review_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/audio_link.dart';
import '../../services/learning_service.dart';
import '../providers/review_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/interactive_word_sentence_card.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
    if (s != null) {
      final langCode =
          context.read<SettingsProvider>().learningLanguageCodes.first;
      await _loadAudioForSentence(s.id(langCode), langCode);
    }
  }

  Future<void> _loadAudioForSentence(
    String sentenceId,
    String languageCode,
  ) async {
    if (!mounted) return;
    setState(() {
      _loadingAudio = true;
      _links = [];
      _position = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
    });

    final links = await context.read<LearningService>().getAudioForSentence(
      sentenceId,
      languageCode,
    );

    if (!mounted) return;
    setState(() {
      _links = links;
      _loadingAudio = false;
    });

    if (links.isNotEmpty) {
      final url = 'https://tatoeba.org/audio/download/${links.first.audioId}';
      await _player.setAudioSource(AudioSource.uri(Uri.parse(url)));
      await _player.play();
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
    final loc = AppLocalizations.of(context)!;

    // build a map of localized labels → quality values:
    final qualityMap = {
      loc.qualityAgain: 0,
      loc.qualityHard: 3,
      loc.qualityGood: 4,
      loc.qualityEasy: 5,
    };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
        ),
        title: Text(loc.review, style: Theme.of(context).textTheme.titleLarge),
      ),
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
                    loc.reviewProgress(review.wordIndex + 1, review.dueWords.length),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),

                // Shared card + audio + nav
                Expanded(
                  child: InteractiveWordSentenceCard(
                    wordText: review.currentWord!.text,
                    sentences: review.sentences,
                    sentenceIndex: review.sentenceIndex,
                    audioLinks: _links,
                    audioLoading: _loadingAudio,
                    isPlaying: _isPlaying,
                    position: _position,
                    duration: _duration,
                    onToggleAudio: _togglePlayPause,
                    onReplayAudio: _togglePlayPause,

                    onPrevSentence: () {
                      review.prevSentence();
                      final nxt = review.currentSentence;
                      if (nxt != null) {
                        final langCode =
                            context
                                .read<SettingsProvider>()
                                .learningLanguageCodes
                                .first;
                        _loadAudioForSentence(
                          nxt.id(langCode),
                          langCode,
                        );
                      }
                    },
                    onNextSentence: () {
                      review.nextSentence();
                      final nxt = review.currentSentence;
                      if (nxt != null) {
                        final langCode =
                            context
                                .read<SettingsProvider>()
                                .learningLanguageCodes
                                .first;
                        _loadAudioForSentence(
                          nxt.id(langCode),
                          langCode,
                        );
                      }
                    },
                  ),
                ),

                // Quality buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: qualityMap.keys.map((label) {
                          return ElevatedButton(
                            onPressed: () async {
                              final q = qualityMap[label]!;
                              await review.markWord(q);
                              final nxt = review.currentSentence;
                              if (nxt != null) {
                                final langCode =
                                    context
                                        .read<SettingsProvider>()
                                        .learningLanguageCodes
                                        .first;
                                _loadAudioForSentence(
                                  nxt.id(langCode),
                                  langCode,
                                );
                              }
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
