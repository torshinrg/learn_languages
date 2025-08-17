import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/sentence.dart';
import '../../domain/repositories/i_sentence_repository.dart';
import 'appwrite_service.dart';

class RemoteSentenceRepository implements ISentenceRepository {
  RemoteSentenceRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Sentence>> fetchByWord(String wordId) async {
    // This requires a join, which is not directly supported by Appwrite.
    // You would typically implement this with a cloud function or by denormalizing data.
    // For now, we'll assume a cloud function or direct API call handles this.
    // This is a placeholder implementation.
    throw UnimplementedError();
  }
}