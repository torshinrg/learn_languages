import '../../core/schema_fields.dart';

class Sentence {
  final String id;
  final String languageId;
  final String content;
  final String? audioUrl;
  final String groupId;
  final String? audioId;
  final List<String> tokenSurfaces;
  final List<String> tokenLemmas;
  final List<String> normalizedWords;
  final String? sentenceType;

  Sentence({
    required this.id,
    required this.languageId,
    required this.content,
    this.audioUrl,
    this.groupId = '',
    this.audioId,
    this.tokenSurfaces = const [],
    this.tokenLemmas = const [],
    this.normalizedWords = const [],
    this.sentenceType,
  });

  factory Sentence.fromMap(Map<String, dynamic> map) {
    final langKey = SchemaFields.sentenceLanguageRef;

    final rawLang =
        map[langKey] ??
        map['languageId'] ??
        map['language'] ??
        map['langId'] ??
        map['language_code'] ??
        '';
    String langId;
    if (rawLang is String) {
      langId = rawLang;
    } else if (rawLang is Map) {
      final idVal = rawLang['\$id'] ?? rawLang['id'];
      langId = idVal is String ? idVal : '';
    } else {
      langId = rawLang?.toString() ?? '';
    }

    // Group id can be string, number, or nested
    final groupKey = SchemaFields.sentenceGroupId;
    final rawGroup = map[groupKey];
    String groupId = '';
    if (rawGroup is String) {
      groupId = rawGroup;
    } else if (rawGroup is num) {
      groupId = rawGroup.toString();
    } else if (rawGroup is Map) {
      final gid = rawGroup['\$id'] ?? rawGroup['id'];
      groupId = gid is String ? gid : '';
    }

    // audio can be a URL string, numeric audio_id, or a storage file relation map
    final rawAudio =
        map['audioUrl'] ??
        map['audio'] ??
        map['audio_url'] ??
        map['audio_id'] ??
        map['audioId'];
    String? audioUrl;
    String? audioId;
    if (rawAudio is String) {
      audioUrl = rawAudio;
      audioId = rawAudio;
    } else if (rawAudio is num) {
      audioUrl = rawAudio.toString();
      audioId = audioUrl;
    } else if (rawAudio is Map) {
      final fid = rawAudio['\$id'] ?? rawAudio['id'];
      audioUrl = fid is String ? fid : null;
      audioId = audioUrl;
    }

    List<String> _safeStringList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return Sentence(
      id: map['\$id'] as String,
      languageId: langId,
      content:
          (map['content'] ?? map['text'] ?? map['sentence'] ?? '') as String,
      audioUrl: audioUrl,
      groupId: groupId,
      audioId: audioId,
      tokenSurfaces: _safeStringList(
        map['tokenSurfaces'] ?? map['token_surface'],
      ),
      tokenLemmas: _safeStringList(map['tokenLemma'] ?? map['token_lemma']),
      normalizedWords: _safeStringList(
        map['normalizedWords'] ?? map['normilized_words'],
      ),
      sentenceType: map['sentenceType']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languageId': languageId,
      'content': content,
      'audioUrl': audioUrl,
      'group_id': groupId,
      'audioId': audioId,
      'tokenSurfaces': tokenSurfaces,
      'tokenLemma': tokenLemmas,
      'normalizedWords': normalizedWords,
      'sentenceType': sentenceType,
    };
  }
}
