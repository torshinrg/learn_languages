import '../entities/task_translation.dart';

abstract class ITaskTranslationRepository {
  Future<TaskTranslation?> fetch(String taskId, String languageCode);
}
