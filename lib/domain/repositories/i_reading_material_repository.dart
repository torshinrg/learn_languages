import '../entities/reading_material.dart';

abstract class IReadingMaterialRepository {
  Future<List<ReadingMaterial>> fetchByLanguage(String languageId);
}
