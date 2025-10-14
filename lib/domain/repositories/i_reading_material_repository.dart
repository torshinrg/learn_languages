import '../entities/reading_material.dart';

abstract class IReadingMaterialRepository {
  Future<List<ReadingMaterial>> listByLanguage(
    String languageId, {
    String? typeName,
    String? search,
  });

  Future<ReadingMaterial?> getById(String id);

  @deprecated
  Future<List<ReadingMaterial>> fetchByLanguage(String languageId) {
    return listByLanguage(languageId);
  }
}
