import 'package:flutter/material.dart';
import 'package:learn_languages/core/di.dart';
import 'package:provider/provider.dart';

import '../providers/task_provider.dart';
import '../widgets/task_widget.dart';

class TasksScreen extends StatelessWidget {
  final String sentenceId;

  const TasksScreen({super.key, required this.sentenceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: ChangeNotifierProvider(
        create: (_) => TaskProvider(getIt(), getIt(), getIt(), getIt(), getIt())..fetchTasksForSentence(sentenceId),
        child: Consumer<TaskProvider>(
          builder: (ctx, provider, child) {
            if (provider.tasks.isEmpty) {
              return const Center(child: Text('No tasks for this sentence.'));
            }
            return ListView.builder(
              itemCount: provider.tasks.length,
              itemBuilder: (ctx, index) {
                final task = provider.tasks[index];
                return TaskWidget(task: task);
              },
            );
          },
        ),
      ),
    );
  }
}