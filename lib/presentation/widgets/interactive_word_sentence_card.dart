import 'package:flutter/material.dart';
import 'package:learn_languages/domain/entities/sentence.dart';
import 'package:learn_languages/domain/entities/word.dart';

class InteractiveWordSentenceCard extends StatelessWidget {
  final Word word;
  final Sentence sentence;
  final VoidCallback onNextSentence;
  final VoidCallback onPrevSentence;

  const InteractiveWordSentenceCard({
    super.key,
    required this.word,
    required this.sentence,
    required this.onNextSentence,
    required this.onPrevSentence,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text(word.text, style: Theme.of(context).textTheme.headlineMedium),
          Text(sentence.content),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onPrevSentence),
              IconButton(icon: const Icon(Icons.arrow_forward), onPressed: onNextSentence),
            ],
          )
        ],
      ),
    );
  }
}