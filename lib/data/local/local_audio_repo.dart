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
      return [];
    }

    final rows = await db.query(
      'sentences_with_audio',
      where: 'sentence_id = ?',
      whereArgs: [sentenceId],
    );

    final result = rows.map((r) => AudioLink.fromMap(r)).toList();

    return result;
  }
}
