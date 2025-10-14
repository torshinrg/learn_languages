class Task {
  final String id;
  final String type;
  final String promptTemplate;
  final String? title;
  final String? description;
  final String? languageId;

  Task({
    required this.id,
    required this.type,
    required this.promptTemplate,
    this.title,
    this.description,
    this.languageId,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    String resolveType() {
      final raw =
          map['type'] ?? map['taskType'] ?? map['category'] ?? map['kind'];
      return raw?.toString() ?? '';
    }

    String resolvePrompt() {
      final raw =
          map['promptTemplate'] ??
          map['prompt_template'] ??
          map['prompt'] ??
          map['body'] ??
          map['text'] ??
          map['content'];
      return raw?.toString() ?? '';
    }

    String? resolveLanguage() {
      final raw =
          map['language'] ??
          map['languageId'] ??
          map['language_id'] ??
          map['lang'];
      if (raw is String) {
        return raw;
      }
      if (raw is Map) {
        final idVal = raw['\$id'] ?? raw['id'];
        if (idVal is String) return idVal;
      }
      return null;
    }

    return Task(
      id: map['\$id'] as String,
      type: resolveType(),
      promptTemplate: resolvePrompt(),
      title: map['title']?.toString(),
      description: map['description']?.toString() ?? map['details']?.toString(),
      languageId: resolveLanguage(),
    );
  }

  Task copyWith({
    String? promptTemplate,
    String? title,
    String? description,
    String? languageId,
  }) {
    return Task(
      id: id,
      type: type,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      title: title ?? this.title,
      description: description ?? this.description,
      languageId: languageId ?? this.languageId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'promptTemplate': promptTemplate,
      'title': title,
      'description': description,
      'language': languageId,
    };
  }
}
