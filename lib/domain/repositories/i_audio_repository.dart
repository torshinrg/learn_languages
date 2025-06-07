// lib/domain/repositories/i_audio_repository.dart

import '../entities/audio_link.dart';

/// Provides audio links associated with sentences.
abstract class IAudioRepository {
  /// Fetch all audio links for the given [sentenceId] in a specific language.
  Future<List<AudioLink>> fetchForSentence(
    String sentenceId,
    String languageCode,
  );
}
