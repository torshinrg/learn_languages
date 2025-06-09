// File: lib/presentation/widgets/task_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/task.dart';
import '../providers/task_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// A generic TaskWidget:
/// - shows [task.description]
/// - renders a “Tap to Speak” button if needed (for sentence‐level tasks)
/// - shows a result area (initially blank)
/// - calls back into TaskProvider to save history
class TaskWidget extends StatefulWidget {
  final Task task;
  const TaskWidget({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  String? _resultText;
  bool _isProcessing = false;

  void _onTapToSpeak() async {
    setState(() => _isProcessing = true);
    // Simulate some speech interaction. Replace with real logic if desired.
    await Future.delayed(const Duration(seconds: 1));
    final fakeResult = 'User spoke something…';

    // Save into history

    await context.read<TaskProvider>().completeScreenTask(
      taskId: widget.task.id,
      result: fakeResult,
    );

    setState(() {
      _isProcessing = false;
      _resultText = fakeResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              loc.exercises_title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.left,
            ),
            Text(
              widget.task.description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!_isProcessing && _resultText == null) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.mic),
                label: Text(loc.tap_to_speak),
                onPressed: _onTapToSpeak,
              ),
            ] else if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                loc.learning_now,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                _resultText!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              /*
              ElevatedButton(
                onPressed: _onTapToSpeak,
                child: Text(loc.tap_to_speak_again),
              ),
              */
            ],
          ],
        ),
      ),
    );
  }
}
