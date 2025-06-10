// lib/presentation/screens/vocabulary_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/word.dart';
import '../providers/vocabulary_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

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
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title:  Text(loc.vocabulary)),
      body: Consumer<VocabularyProvider>(
        builder: (_, vm, __) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(loc.learning_now, vm.learningNow),
              const SizedBox(height: 16),
              _buildSection(loc.pending, vm.pending),
              const SizedBox(height: 16),
              _buildSection(loc.mastered, vm.learned),
            ],
          );
        },
      ),
    );
  }
}
