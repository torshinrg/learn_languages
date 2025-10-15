import '../entities/sentence_task.dart';

abstract class ISentenceTaskRepository {
  Future<List<SentenceTask>> fetchBySentence(String sentenceId);
}
