// lib/presentation/screens/vocabulary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/word.dart';
import '../providers/vocabulary_provider.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({Key? key}) : super(key: key);

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  late VocabularyProvider _vocab;

  @override
  void initState() {
    super.initState();
    _vocab = context.read<VocabularyProvider>();
    _vocab.refresh();
  }

  Widget _buildSection(String title, List<Word> items) {
    return ExpansionTile(
      title: Text('$title (${items.length})'),
      children: items.map((w) => ListTile(
        title: Text(w.text),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary')),
      body: Consumer<VocabularyProvider>(
        builder: (_, vm, __) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection('Learning Now', vm.learningNow),
              const SizedBox(height: 16),
              _buildSection('Pending', vm.pending),
              const SizedBox(height: 16),
              _buildSection('Mastered', vm.learned),
            ],
          );
        },
      ),
    );
  }
}
