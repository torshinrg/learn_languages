import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/language.dart';
import '../../domain/repositories/i_language_repository.dart';
import 'appwrite_service.dart';

class RemoteLanguageRepository implements ILanguageRepository {
  RemoteLanguageRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Language>> fetchAll() async {
    final docs = await _service.getDocuments(
      databaseId: kAppwriteDatabaseId,
      collectionId: kAppwriteLanguages,
    );
    return docs.map((d) => Language.fromMap(d.data)).toList();
  }
}
