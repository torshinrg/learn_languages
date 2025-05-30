// lib/presentation/screens/custom_words_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/custom_words_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class CustomWordsScreen extends StatefulWidget {
  final String? initialText;
  const CustomWordsScreen({Key? key, this.initialText}) : super(key: key);

  @override
  State<CustomWordsScreen> createState() => _CustomWordsScreenState();
}

class _CustomWordsScreenState extends State<CustomWordsScreen> {
  late final TextEditingController _ctrl;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText ?? '');
    _focusNode = FocusNode();
    // wait until build finishes, then focus:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CustomWordsProvider>();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title:  Text(loc.add_custom_word)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,            // ← auto-focus here
                    controller: _ctrl,
                    decoration:  InputDecoration(
                      labelText: loc.new_word,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    final text = _ctrl.text.trim();
                    if (text.isEmpty) return;
                    context.read<CustomWordsProvider>().add(text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${loc.added} “$text”')),
                    );
                    _ctrl.clear();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: vm.words.length,
              itemBuilder: (_, i) {
                final w = vm.words[i];
                return ListTile(
                  title: Text(w.text),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () =>
                        context.read<CustomWordsProvider>().remove(w.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
