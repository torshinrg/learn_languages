// lib/presentation/widgets/word_sentence_card.dart

import 'package:flutter/material.dart';
import '../../domain/entities/audio_link.dart';
import '../../domain/entities/sentence.dart';

/// Displays the word, example sentence + translation,
/// handles auto-play of audio, manual replay via speaker icon,
/// inline “Tap to Speak” area and result actions.
class WordSentenceCard extends StatefulWidget {
  final String wordText;
  final List<Sentence> sentences;
  final int sentenceIndex;

  final bool audioLoading;
  final List<AudioLink> audioLinks;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  /// Called to play/pause audio.
  final VoidCallback onToggleAudio;
  /// Called when user taps the speaker icon.
  final VoidCallback onReplayAudio;
  /// Navigate to previous example sentence.
  final VoidCallback onPrevSentence;
  /// Navigate to next example sentence.
  final VoidCallback onNextSentence;

  /// Called when the user taps “Tap to Speak”.
  final VoidCallback onTapToSpeak;
  /// If non-null, displays the user’s score [0..1].
  final double? resultScore;
  /// Called to skip to the next *word* after scoring.
  final VoidCallback? onNextWord;

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
    required this.onReplayAudio,
    required this.onPrevSentence,
    required this.onNextSentence,
    required this.onTapToSpeak,
    this.resultScore,
    this.onNextWord,
  }) : super(key: key);

  @override
  State<WordSentenceCard> createState() => _WordSentenceCardState();
}

class _WordSentenceCardState extends State<WordSentenceCard> {
  bool _hasAutoPlayed = false;

  @override
  void didUpdateWidget(covariant WordSentenceCard old) {
    super.didUpdateWidget(old);
    // as soon as audioLinks become non-empty and we haven't auto-played yet:
    if (!_hasAutoPlayed &&
        !widget.audioLoading &&
        widget.audioLinks.isNotEmpty) {
      _hasAutoPlayed = true;
      widget.onToggleAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = widget.sentences.isNotEmpty
        ? widget.sentences[widget.sentenceIndex]
        : null;

    return Column(
      children: [
        // ─── Card with word & sentence ────────────────────────────────
        SizedBox(
          width: 350,
          child: Card(
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            color: theme.cardTheme.color,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Word
                  SelectableText(
                    widget.wordText,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Sentence + speaker icon
                  if (current != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              SelectableText(
                                current.spanish,
                                style: theme.textTheme.titleMedium!
                                    .copyWith(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              SelectableText(
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

                        // speaker icon for replay
                        IconButton(
                          icon: Icon(
                            Icons.volume_up,
                            color: theme.primaryColor,
                          ),
                          onPressed: widget.onReplayAudio,
                        ),
                      ],
                    )
                  else
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
          ),
        ),

        // ─── Audio progress bar (optional) ────────────────────────────
        if (widget.audioLoading)
          const SizedBox(
              height: 56, child: Center(child: CircularProgressIndicator()))
        else if (widget.audioLinks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    widget.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: theme.primaryColor,
                  ),
                  onPressed: widget.onToggleAudio,
                ),
                Expanded(
                  child: LinearProgressIndicator(
                    value: widget.duration.inMilliseconds > 0
                        ? widget.position.inMilliseconds /
                        widget.duration.inMilliseconds
                        : 0,
                  ),
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

        const SizedBox(height: 8),

        // ─── Sentence nav ──────────────────────────────────────────────
        Padding(
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
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: widget.onNextSentence,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Inline “Tap to Speak” or Result View ──────────────────────
        if (widget.resultScore == null) ...[
          // initial state: invite to record
          OutlinedButton.icon(
            icon: const Icon(Icons.mic),
            label: const Text('Tap to Speak'),
            onPressed: widget.onTapToSpeak,
          ),
        ] else ...[
          // show percentage + two action buttons
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: widget.resultScore! >= 0.6
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${(widget.resultScore! * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.headlineMedium!
                      .copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.resultScore! >= 0.6
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onNextWord,
                        child: const Text('Next Word'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onNextSentence,
                        child: const Text('Next Sentence'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}
