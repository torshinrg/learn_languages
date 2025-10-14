class ReadingMaterial {
  final String id;
  final String languageId;
  final String title;
  final String typeName;
  final String? author;
  final String? source;
  final String? license;
  final String? sourceUrl;
  final String? slug;
  final String? rawText;

  ReadingMaterial({
    required this.id,
    required this.languageId,
    required this.title,
    required this.typeName,
    this.author,
    this.source,
    this.license,
    this.sourceUrl,
    this.slug,
    this.rawText,
  });

  factory ReadingMaterial.fromMap(Map<String, dynamic> map) {
    final languageRelation = map['languages'];
    String languageId;
    if (languageRelation is String) {
      languageId = languageRelation;
    } else if (languageRelation is Map) {
      languageId =
          (languageRelation['\$id'] ?? languageRelation['id'] ?? '').toString();
    } else {
      languageId =
          (map['languageId'] ??
                  map['language'] ??
                  map['langId'] ??
                  map['language_code'] ??
                  '')
              .toString();
    }

    // `materialsTypes` relation may arrive as map or list with embedded data.
    String resolvedTypeName = 'unknown';
    final typeRelation = map['materialsTypes'];
    if (typeRelation is Map) {
      resolvedTypeName =
          (typeRelation['type_name'] ??
                  typeRelation['material_type'] ??
                  typeRelation['name'] ??
                  resolvedTypeName)
              .toString();
    } else if (typeRelation is List && typeRelation.isNotEmpty) {
      final first = typeRelation.first;
      if (first is Map) {
        resolvedTypeName =
            (first['type_name'] ??
                    first['material_type'] ??
                    first['name'] ??
                    resolvedTypeName)
                .toString();
      } else if (first is String) {
        resolvedTypeName = first;
      }
    } else if (typeRelation is String) {
      resolvedTypeName = typeRelation;
    } else if (map.containsKey('type')) {
      resolvedTypeName = map['type'].toString();
    }

    return ReadingMaterial(
      id: map['\$id'] as String,
      languageId: languageId,
      title: (map['title'] ?? map['name'] ?? 'Untitled').toString(),
      typeName: resolvedTypeName,
      author: _nullableString(map['author']),
      source: _nullableString(map['source']),
      license: _nullableString(map['license'] ?? map['licence']),
      sourceUrl: _nullableString(map['sourceUrl'] ?? map['source_url']),
      slug: _nullableString(map['slug']),
      rawText: _nullableString(map['rawText'] ?? map['raw_text']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'languageId': languageId,
      'title': title,
      'typeName': typeName,
      'author': author,
      'source': source,
      'license': license,
      'sourceUrl': sourceUrl,
      'slug': slug,
      'rawText': rawText,
    };
  }
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  if (str.isEmpty) return null;
  return str;
}
