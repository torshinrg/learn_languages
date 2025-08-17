import '../entities/task.dart';

abstract class ITaskRepository {
  Future<List<Task>> fetchBySentence(String sentenceId);
}