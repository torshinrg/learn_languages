import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';

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

  AppwriteService({required this.endpoint, required this.projectId}) {
    client = Client()
      ..setEndpoint(endpoint)
      ..setProject(projectId)
      ..setSelfSigned(status: true);
    account = Account(client);
    databases = Databases(client);
  }

  /// Create a new user account.
  Future<User?> register({
    required String email,
    required String password,
    String? name,
  }) async {
    try {
      return await account.create(
        userId: ID.unique(),
        email: email,
        password: password,
        name: name,
      );
    } on AppwriteException {
      return null;
    }
  }

  /// Sign in using email and password.
  Future<Session?> login({
    required String email,
    required String password,
  }) async {
    try {
      return await account.createEmailSession(
        email: email,
        password: password,
      );
    } on AppwriteException {
      return null;
    }
  }

  /// Delete all sessions for the current account.
  Future<void> logout() async {
    try {
      await account.deleteSessions();
    } on AppwriteException {
      // ignore
    }
  }

  /// Retrieve documents from a collection. Optional [queries] can be used
  /// for filtering and sorting.
  Future<List<Document>> getDocuments({
    required String databaseId,
    required String collectionId,
    List<Query>? queries,
  }) async {
    final result = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: collectionId,
      queries: queries,
    );
    return result.documents;
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
}
