// lib/data/local/local_audio_repo.dart
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/audio_link.dart';
import '../../domain/repositories/i_audio_repository.dart';
import '../../core/app_language.dart';

class LocalAudioRepository implements IAudioRepository {
  final Database db;
  LocalAudioRepository(this.db);

  @override
  Future<List<AudioLink>> fetchForSentence(
    String sentenceId,
    String languageCode,
  ) async {
    // Determine table based on language code
    final lang = AppLanguageExtension.fromCode(languageCode);
    if (lang == null) {
      print('⚠️ [LocalAudioRepo] Unsupported languageCode="$languageCode"');
      return [];
    }
    final table = '${lang.name}_audio';

    // Логируем входящие параметры
    print(
        '🔍 [LocalAudioRepo] fetchForSentence sentenceId=$sentenceId table=$table');

    // Выполняем запрос
    final rows = await db.query(
      table,
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