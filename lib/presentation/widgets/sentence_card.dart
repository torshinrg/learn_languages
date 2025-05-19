// lib/presentation/widgets/sentence_card.dart

import 'package:flutter/material.dart';


class SentenceCard extends StatelessWidget {
  final String word;
  final String sentence;
  final String translation;
  final Widget audioSection;
  final String pageIndicator;
  final VoidCallback onPrevSentence;
  final VoidCallback onNextSentence;

  const SentenceCard({
    Key? key,
    required this.word,
    required this.sentence,
    required this.translation,
    required this.audioSection,
    required this.pageIndicator,
    required this.onPrevSentence,
    required this.onNextSentence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  word,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  sentence,
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  translation,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontStyle: FontStyle.italic, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                audioSection,
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onPrevSentence,
              ),
              Expanded(child: Center(child: Text(pageIndicator))),
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
