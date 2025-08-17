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
          return Column(
            children: [
              Expanded(
                child: InteractiveWordSentenceCard(
                  key: ValueKey(provider.currentWord!),
                  word: provider.currentWord!,
                  sentence: provider.currentSentence!,
                  onNextSentence: provider.nextSentence,
                  onPrevSentence: provider.prevSentence,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(onPressed: () => provider.markWord(WordStatus.inProgress), child: const Text('Got it!')),
                ],
              )
            ],
          );
        },
      ),
    );
  }
}