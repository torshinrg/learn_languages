import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/domain/repositories/i_user_word_status_repository.dart';

class MarkLearned {
  final IUserWordStatusRepository _userWordStatusRepository;

  MarkLearned(this._userWordStatusRepository);

  Future<void> call(String userId, String wordId, WordStatus status) {
    return _userWordStatusRepository.update(UserWordStatus(id: '', userId: userId, wordId: wordId, status: status));
  }
}