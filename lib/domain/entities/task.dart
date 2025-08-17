class Task {
  final String id;
  final String type;
  final String promptTemplate;

  Task({
    required this.id,
    required this.type,
    required this.promptTemplate,
  });

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['\$id'] as String,
      type: map['type'] as String,
      promptTemplate: map['promptTemplate'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'promptTemplate': promptTemplate,
    };
  }
}