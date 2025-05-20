// File: lib/presentation/widgets/word_sentence_card.dart

import 'package:flutter/material.dart';
import '../../domain/entities/audio_link.dart';
import '../../domain/entities/sentence.dart';

/// Displays a centered card with fixed horizontal width containing
/// the word + sentence/translation, then audio controls and navigation.
class WordSentenceCard extends StatelessWidget {
  final String wordText;
  final List<Sentence> sentences;
  final int sentenceIndex;
  final bool audioLoading;
  final List<AudioLink> audioLinks;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onToggleAudio;
  final VoidCallback onPrevSentence;
  final VoidCallback onNextSentence;

  static const double _cardWidth = 350;

  const WordSentenceCard({
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
    required this.onPrevSentence,
    required this.onNextSentence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current =
    sentences.isNotEmpty ? sentences[sentenceIndex] : null;

    return Column(
      children: [
        // Centered card with fixed width
        Expanded(
          child: Center(
            child: SizedBox(
              width: _cardWidth,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                color: theme.cardTheme.color,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        wordText,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (current == null)
                        const Center(child: CircularProgressIndicator())
                      else
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Text(
                                  current.spanish,
                                  style: theme.textTheme.titleMedium!
                                      .copyWith(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  current.english,
                                  style: theme.textTheme.bodyMedium!
                                      .copyWith(
                                    fontStyle: FontStyle.italic,
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

        const SizedBox(height: 8),

        // Audio controls
        if (audioLoading)
          const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (audioLinks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon:
                      Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: onToggleAudio,
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: duration.inMilliseconds > 0
                            ? position.inMilliseconds /
                            duration.inMilliseconds
                            : 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Recorded by ${audioLinks.first.username}.',
                  style: theme.textTheme.bodySmall,
                ),
                if (audioLinks.first.license.isNotEmpty)
                  Text(
                    'License: ${audioLinks.first.license}.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          )
        else
          const SizedBox(
            height: 56,
            child: Center(
              child: Text(
                'No audio available.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ),

        // Prev/Next buttons
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onPrevSentence,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    sentences.isNotEmpty
                        ? '${sentenceIndex + 1} / ${sentences.length}'
                        : '0 / 0',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: onNextSentence,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
