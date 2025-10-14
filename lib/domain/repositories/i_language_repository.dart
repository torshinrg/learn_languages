import '../entities/language.dart';

abstract class ILanguageRepository {
  Future<List<Language>> fetchAll();
}
