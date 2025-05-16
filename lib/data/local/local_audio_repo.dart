// lib/data/local/local_audio_repo.dart
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/audio_link.dart';
import '../../domain/repositories/i_audio_repository.dart';

class LocalAudioRepository implements IAudioRepository {
  final Database db;
  LocalAudioRepository(this.db);

  @override
  Future<List<AudioLink>> fetchForSentence(String sentenceId) async {
    // Логируем входящий sentenceId
    print('🔍 [LocalAudioRepo] fetchForSentence sentenceId=$sentenceId');
    // Выполняем запрос
    final rows = await db.query(
      'sentences_with_audio',
      where: 'sentence_id = ?',
      whereArgs: [sentenceId],
    );
    // Логируем сырые данные из БД
    print('🔍 [LocalAudioRepo] rows.length=${rows.length}, rows=$rows');
    // Преобразуем в сущности
    final result = rows.map((r) => AudioLink.fromMap(r)).toList();
    // Логируем итоговый список
    print('🔍 [LocalAudioRepo] parsed AudioLink objects: $result');
    return result;
  }
}