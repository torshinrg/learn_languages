// File: lib/presentation/providers/task_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/i_task_repository.dart';

/// Provides tasks of a given type and locale, and saves history.
class TaskProvider extends ChangeNotifier {
  final ITaskRepository _taskRepo;
  final Locale Function() _localeSelector;

  TaskProvider(this._taskRepo, this._localeSelector) {
    // As soon as the provider is created, load tasks for the current locale:
    _initialize();
  }

  List<Task> _sentenceTasks = [];
  List<Task> get sentenceTasks => List.unmodifiable(_sentenceTasks);

  List<Task> _screenTasks = [];
  List<Task> get screenTasks => List.unmodifiable(_screenTasks);

  Future<void> _initialize() async {
    // Print out which locale we’re about to load:
    final localeCode = _localeSelector().languageCode;
    await loadAllTasks();
  }

  /// Load tasks of both types (“sentence” and “screen”) for current UI locale.
  Future<void> loadAllTasks() async {
    final localeCode = _localeSelector().languageCode;

    // Fetch all “sentence” tasks for this locale
    final fetchedSentences = await _taskRepo.fetchTasksByType(
      'sentence',
      localeCode,
    );
    _sentenceTasks = fetchedSentences;
    for (var t in _sentenceTasks) {}

    // Fetch all “screen” tasks for this locale
    final fetchedScreens = await _taskRepo.fetchTasksByType(
      'screen',
      localeCode,
    );
    _screenTasks = fetchedScreens;
    for (var t in _screenTasks) {}

    notifyListeners();
  }

  /// Called when user completes a task (type “sentence”) on a specific sentenceId.
  Future<void> completeSentenceTask({
    required String taskId,
    required String sentenceId,
    required String? result,
  }) async {
    await _taskRepo.saveTaskHistory(
      taskId: taskId,
      sentenceId: sentenceId,
      result: result,
    );
    // Optionally remove it from the in‐memory list so it never reappears:
    // _sentenceTasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  /// Called when user completes a “screen‐level” task (no sentenceId).
  Future<void> completeScreenTask({
    required String taskId,
    required String? result,
  }) async {
    await _taskRepo.saveTaskHistory(
      taskId: taskId,
      sentenceId: null,
      result: result,
    );
    // Optionally remove it from _screenTasks if it should be one‐time:
    // _screenTasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }
}
