import 'package:appwrite/appwrite.dart';

import '../../core/constants.dart';
import '../../domain/entities/task.dart';
import '../../domain/repositories/i_task_repository.dart';
import 'appwrite_service.dart';

class RemoteTaskRepository implements ITaskRepository {
  RemoteTaskRepository(this._service);

  final AppwriteService _service;

  @override
  Future<List<Task>> fetchBySentence(String sentenceId) async {
    // This requires a join, which is not directly supported by Appwrite.
    // You would typically implement this with a cloud function or by denormalizing data.
    // For now, we'll assume a cloud function or direct API call handles this.
    // This is a placeholder implementation.
    throw UnimplementedError();
  }
}