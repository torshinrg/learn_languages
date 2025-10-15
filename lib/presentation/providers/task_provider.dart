import 'package:flutter/material.dart';
import 'package:learn_languages/domain/entities/sentence_task.dart';
import 'package:learn_languages/domain/entities/task.dart';
import 'package:learn_languages/domain/entities/user_sentence_task.dart';
import 'package:learn_languages/domain/repositories/i_sentence_task_repository.dart';
import 'package:learn_languages/domain/repositories/i_task_repository.dart';
import 'package:learn_languages/domain/repositories/i_user_sentence_task_repository.dart';
import 'package:learn_languages/presentation/providers/settings_provider.dart';

import '../../data/remote/appwrite_service.dart';

class TaskProvider extends ChangeNotifier {
  final ITaskRepository _taskRepo;
  final ISentenceTaskRepository _sentenceTaskRepo;
  final IUserSentenceTaskRepository _userSentenceTaskRepo;
  final AppwriteService _appwriteService;
  final SettingsProvider _settings;

  TaskProvider(
    this._taskRepo,
    this._sentenceTaskRepo,
    this._userSentenceTaskRepo,
    this._appwriteService,
    this._settings,
  );

  List<Task> _tasks = [];
  List<Task> get tasks => List.unmodifiable(_tasks);

  Future<void> fetchTasksForSentence(String sentenceId) async {
    final sentenceTasks = await _sentenceTaskRepo.fetchBySentence(sentenceId);
    final taskIds = sentenceTasks.map((st) => st.taskId).toList();

    // This is inefficient. In a real app, you'd fetch these in a single query
    // or have the data denormalized.
    final List<Task> fetchedTasks = [];
    for (var id in taskIds) {
      // This is a placeholder for fetching the actual task content.
      // You'll need to implement a fetchById in your ITaskRepository.
      // fetchedTasks.add(await _taskRepo.fetchById(id));
    }
    _tasks = fetchedTasks;
    notifyListeners();
  }

  Future<void> completeTask({
    required String sentenceTaskId,
    required String response,
  }) async {
    try {
      final user = await _appwriteService.account.get();
      final userTask = UserSentenceTask(
        id: '', // Appwrite will generate this
        userId: user.$id,
        sentenceTaskId: sentenceTaskId,
        completed: true,
        response: response,
        completedAt: DateTime.now(),
      );
      await _userSentenceTaskRepo.createOrUpdate(userTask);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }
}