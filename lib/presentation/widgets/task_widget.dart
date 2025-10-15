import 'package:flutter/material.dart';
import 'package:learn_languages/domain/entities/task.dart';

class TaskWidget extends StatelessWidget {
  final Task task;

  const TaskWidget({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(task.type),
        subtitle: Text(task.promptTemplate),
      ),
    );
  }
}