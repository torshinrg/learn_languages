import 'package:learn_languages/data/local/local_user_word_status_repo.dart';
import 'package:learn_languages/data/remote/appwrite_service.dart';
import 'package:learn_languages/data/remote/remote_user_word_status_repo.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';
import 'package:learn_languages/domain/repositories/i_user_word_status_repository.dart';

/// Routes calls to a local or remote implementation based on auth state.
///
/// - If logged in (non-anonymous), use remote Appwrite collection.
/// - Otherwise, store and read from local sqflite.
class AdaptiveUserWordStatusRepository implements IUserWordStatusRepository {
  final AppwriteService _appwrite;
  final RemoteUserWordStatusRepository _remote;
  final LocalUserWordStatusRepository _local;

  AdaptiveUserWordStatusRepository({
    required AppwriteService appwrite,
    required RemoteUserWordStatusRepository remote,
    required LocalUserWordStatusRepository local,
  })  : _appwrite = appwrite,
        _remote = remote,
        _local = local;

  bool get _useRemote => _appwrite.isLoggedIn;

  @override
  Future<void> create(UserWordStatus status) async {
    if (_useRemote) {
      return _remote.create(status);
    }
    return _local.create(status);
  }

  @override
  Future<void> update(UserWordStatus status) async {
    if (_useRemote) {
      return _remote.update(status);
    }
    return _local.update(status);
  }

  @override
  Future<UserWordStatus> fetch(String userId, String wordId) async {
    if (_useRemote) {
      return _remote.fetch(userId, wordId);
    }
    return _local.fetch(userId, wordId);
  }

  @override
  Future<List<UserWordStatus>> fetchByStatus(String userId, WordStatus status) async {
    if (_useRemote) {
      return _remote.fetchByStatus(userId, status);
    }
    return _local.fetchByStatus(userId, status);
  }

  @override
  Future<int> count(String userId, WordStatus status) async {
    if (_useRemote) {
      return _remote.count(userId, status);
    }
    return _local.count(userId, status);
  }
}

