// File: lib/presentation/screens/task_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../widgets/task_widget.dart';
import '../../domain/entities/task.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text('Tasks')),
      body: FutureBuilder<void>(
        future: context.read<TaskProvider>().loadAllTasks(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final allScreenTasks = context.watch<TaskProvider>().screenTasks
              .where((t) => t.taskType == 'screen')
              .toList();

          if (allScreenTasks.isEmpty) {
            return Center(child: Text('No tasks for this locale.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: allScreenTasks.length,
            itemBuilder: (_, i) {
              final t = allScreenTasks[i];
              return TaskWidget(task: t, );
            },
          );
        },
      ),
    );
  }
}
