import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/user_word_status.dart';
import '../providers/study_provider.dart';
import '../widgets/interactive_word_sentence_card.dart';

class StudyScreen extends StatelessWidget {
  const StudyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study')),
      body: Consumer<StudyProvider>(
        builder: (ctx, provider, child) {
          if (!provider.initialLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.words.isEmpty) {
            return const Center(child: Text('No new words to study!'));
          }
          final currentWord = provider.currentWord!;
          if (provider.sentences.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(currentWord.text, style: Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 16),
                            const Text('No example sentences available yet.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => provider.markWord(WordStatus.inProgress),
                      child: const Text('Got it → Next word'),
                    ),
                    TextButton(
                      onPressed: () => provider.markWord(WordStatus.known),
                      child: const Text('Mark as Known'),
                    )
                  ],
                )
              ],
            );
          }
          return Column(
            children: [
              Expanded(
                child: InteractiveWordSentenceCard(
                  key: ValueKey(currentWord),
                  word: currentWord,
                  sentences: provider.sentences,
                  translationsByGroup: provider.translationsMap,
                  onNextWord: () => provider.markWord(WordStatus.inProgress),
                  onMarkKnown: () => provider.markWord(WordStatus.known),
                ),
              ),
              // Footer actions are handled inside the card via End Card
            ],
          );
        },
      ),
    );
  }
}
