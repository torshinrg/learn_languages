import '../entities/material_sentence.dart';

abstract class IMaterialSentenceRepository {
  Future<List<MaterialSentence>> fetchByMaterial(String materialId);
}
