import '../entities/word_sentence_link.dart';

abstract class IWordSentenceLinkRepository {
  Future<List<WordSentenceLink>> fetchByWord(String wordId);
}
