import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/domain/repositories/i_user_word_status_repository.dart';

class GetDueReviews {
  final IUserWordStatusRepository _userWordStatusRepository;

  GetDueReviews(this._userWordStatusRepository);

  Future<List<UserWordStatus>> call(String userId) {
    return _userWordStatusRepository.fetchByStatus(userId, WordStatus.inProgress);
  }
}