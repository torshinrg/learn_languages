import 'package:appwrite/appwrite.dart';
import 'dart:io' as io;
import 'package:appwrite/models.dart';
import 'package:learn_languages/domain/entities/user_word_status.dart';

import '../../domain/repositories/i_user_word_status_repository.dart';
import '../../domain/repositories/i_word_repository.dart';

/// A minimal wrapper around the Appwrite SDK used for authentication
/// and common database operations.
class AppwriteService {
  /// Appwrite endpoint, e.g. 'https://cloud.appwrite.io/v1'.
  final String endpoint;

  /// The Appwrite project ID.
  final String projectId;

  late final Client client;
  late final Account account;
  late final Databases databases;
  late final Storage storage;

  late final IWordRepository _wordRepository;
  late final IUserWordStatusRepository _userWordStatusRepository;
  bool _isLoggedIn = false; // true after email/password login

  AppwriteService({required this.endpoint, required this.projectId}) {
    client =
        Client()
          ..setEndpoint(endpoint)
          ..setProject(projectId)
          ..setSelfSigned(status: true);
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
  }

  /// Download a file from Appwrite Storage to a temporary path and return it.
  /// Returns null on failure.
  Future<String?> downloadFileToTemp({
    required String bucketId,
    required String fileId,
    String prefix = 'audio_',
  }) async {
    try {
      final bytes = await storage.getFileDownload(
        bucketId: bucketId,
        fileId: fileId,
      );
      // Write to a temp file
      final tempDir = await getTemporaryDirectoryPath();
      final path = '$tempDir/${prefix}${fileId}.bin';
      final file = io.File(path);
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Portable way to get a temp dir path without importing Flutter deps here.
  Future<String> getTemporaryDirectoryPath() async {
    // Use system tmp directory via dart:io
    return io.Directory.systemTemp.createTemp('ll_tmp_').then((d) => d.path);
  }

  void init({
    required IWordRepository wordRepository,
    required IUserWordStatusRepository userWordStatusRepository,
  }) {
    _wordRepository = wordRepository;
    _userWordStatusRepository = userWordStatusRepository;
  }

  bool get isLoggedIn => _isLoggedIn;

  /// Create a new user account.
  Future<User?> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      final user = await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );

      // Create initial user word statuses
      final words = await _wordRepository.fetchTopN('en', 100);
      for (final word in words) {
        await _userWordStatusRepository.create(
          UserWordStatus(
            id: ID.unique(),
            userId: user.$id,
            wordId: word.id,
            status: WordStatus.New,
          ),
        );
      }

      return user;
    } on AppwriteException {
      return null;
    }
  }

  /// Sign in using email and password.
  Future<Session?> login({
    required String email,
    required String password,
  }) async {
    print('Attempting to log in with email: $email');
    try {
      final session = await account.createEmailPasswordSession(
        email: email,
        password: password,
      );
      print('Login successful. Session ID: ${session.$id}');
      _isLoggedIn = true;

      // Check if user has word statuses
      final statuses = await _userWordStatusRepository.count(
        session.userId,
        WordStatus.New,
      );
      if (statuses == 0) {
        // Create initial user word statuses
        final words = await _wordRepository.fetchTopN('en', 100);
        for (final word in words) {
          await _userWordStatusRepository.create(
            UserWordStatus(
              id: ID.unique(),
              userId: session.userId,
              wordId: word.id,
              status: WordStatus.New,
            ),
          );
        }
      }

      return session;
    } on AppwriteException catch (e) {
      print('Appwrite exception during login: ${e.message}');
      return null;
    }
  }

  /// Create an anonymous session if none exists.
  Future<void> ensureAnonymousSession() async {
    try {
      await account.get();
    } on AppwriteException {
      try {
        await account.createAnonymousSession();
      } on AppwriteException {
        // ignore
      }
    }
  }

  /// Delete all sessions for the current account.
  Future<void> logout() async {
    try {
      await account.deleteSessions();
    } on AppwriteException {
      // ignore
    }
    _isLoggedIn = false;
  }

  /// Retrieve documents with metadata from a collection.
  Future<DocumentList> listDocumentsRaw({
    required String databaseId,
    required String collectionId,
    List<String>? queries,
    bool retried = false,
  }) async {

    try {
      final result = await databases.listDocuments(
        databaseId: databaseId,
        collectionId: collectionId,
        queries: queries,
      );
      if (result.total == 0 || result.documents.isEmpty) {

      } else {
        final sampleKeys = result.documents.first.data.keys.take(5).join(', ');

      }
      return result;
    } on AppwriteException catch (e) {
      print(
        '[AppwriteService] listDocuments failed: code=${e.code} message=${e.message}',
      );
      if (e.code == 401 && !retried) {
        print('[AppwriteService] attempting to ensure anonymous session…');
        await ensureAnonymousSession();
        return listDocumentsRaw(
          databaseId: databaseId,
          collectionId: collectionId,
          queries: queries,
          retried: true,
        );
      }
      rethrow;
    }
  }

  /// Retrieve documents from a collection. Optional [queries] can be used
  /// for filtering and sorting.
  Future<List<Document>> getDocuments({
    required String databaseId,
    required String collectionId,
    List<String>? queries,
  }) async {
    final result = await listDocumentsRaw(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: queries,
    );
    return result.documents;
  }

  /// Retrieve a single document by its ID.
  Future<Document> getDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    bool retried = false,
  }) async {
    try {
      final result = await databases.getDocument(
        databaseId: databaseId,
        collectionId: collectionId,
        documentId: documentId,
      );
      final sampleKeys = result.data.keys.take(5).join(', ');

      return result;
    } on AppwriteException catch (e) {
      print(
        '[AppwriteService] getDocument failed: code=${e.code} message=${e.message}',
      );
      if (e.code == 401 && !retried) {
        print('[AppwriteService] attempting to ensure anonymous session…');
        await ensureAnonymousSession();
        return getDocument(
          databaseId: databaseId,
          collectionId: collectionId,
          documentId: documentId,
          retried: true,
        );
      }
      rethrow;
    }
  }

  /// Create a new document in a collection.
  Future<Document> createDocument({
    required String databaseId,
    required String collectionId,
    required Map<String, dynamic> data,
    String? documentId,
  }) async {
    return await databases.createDocument(
      databaseId: databaseId,
      collectionId: collectionId,
      documentId: documentId ?? ID.unique(),
      data: data,
    );
  }

  /// Update an existing document.
  Future<Document> updateDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    return await databases.updateDocument(
      databaseId: databaseId,
      collectionId: collectionId,
      documentId: documentId,
      data: data,
    );
  }

  /// Delete a document from a collection.
  Future<void> deleteDocument({
    required String databaseId,
    required String collectionId,
    required String documentId,
  }) async {
    await databases.deleteDocument(
      databaseId: databaseId,
      collectionId: collectionId,
      documentId: documentId,
    );
  }
}
