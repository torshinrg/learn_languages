// lib/domain/entities/audio_link.dart
class AudioLink {
  final String sentenceId;
  final String audioId;
  final String username;
  final String license;
  final String link;

  AudioLink({
    required this.sentenceId,
    required this.audioId,
    required this.username,
    required this.license,
    required this.link,
  });

  factory AudioLink.fromMap(Map<String, dynamic> map) {
    return AudioLink(
      sentenceId: map['sentence_id'] as String,
      audioId: map['audio_id'] as String,
      username: map['username'] as String,
      license: map['license'] as String,
      link: map['link'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sentence_id': sentenceId,
      'audio_id': audioId,
      'username': username,
      'license': license,
      'link': link,
    };
  }
}
