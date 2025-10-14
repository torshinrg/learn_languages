import '../entities/material_sentence.dart';

abstract class IMaterialSentenceRepository {
  Future<MaterialSentencePage> fetchByMaterial(
    String materialId, {
    int? limit,
    int? startAfterOrder,
  });
}
