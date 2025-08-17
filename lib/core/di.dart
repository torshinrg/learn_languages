import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:learn_languages/data/remote/appwrite_service.dart';
import 'package:learn_languages/data/remote/remote_language_repo.dart';
import 'package:learn_languages/data/remote/remote_material_sentence_repo.dart';
import 'package:learn_languages/data/remote/remote_reading_material_repo.dart';
import 'package:learn_languages/data/remote/remote_sentence_repo.dart';
import 'package:learn_languages/data/remote/remote_sentence_task_repo.dart';
import 'package:learn_languages/data/remote/remote_task_repo.dart';
import 'package:learn_languages/data/remote/remote_task_translation_repo.dart';
import 'package:learn_languages/data/remote/remote_user_sentence_task_repo.dart';
import 'package:learn_languages/data/remote/remote_user_vocabulary_repo.dart';
import 'package:learn_languages/data/remote/remote_user_word_status_repo.dart';
import 'package:learn_languages/data/remote/remote_word_repo.dart';
import 'package:learn_languages/data/remote/remote_word_sentence_link_repo.dart';
import 'package:learn_languages/domain/repositories/i_language_repository.dart';
import 'package:learn_languages/domain/repositories/i_material_sentence_repository.dart';
import 'package:learn_languages/domain/repositories/i_reading_material_repository.dart';
import 'package:learn_languages/domain/repositories/i_sentence_repository.dart';
import 'package:learn_languages/domain/repositories/i_sentence_task_repository.dart';
import 'package:learn_languages/domain/repositories/i_task_repository.dart';
import 'package:learn_languages/domain/repositories/i_task_translation_repository.dart';
import 'package:learn_languages/domain/repositories/i_user_sentence_task_repository.dart';
import 'package:learn_languages/domain/repositories/i_user_vocabulary_repository.dart';
import 'package:learn_languages/domain/repositories/i_user_word_status_repository.dart';
import 'package:learn_languages/domain/repositories/i_word_repository.dart';
import 'package:learn_languages/domain/repositories/i_word_sentence_link_repository.dart';
import 'package:learn_languages/services/learning_service.dart';
import 'package:learn_languages/services/notification_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupLocator() async {
  await dotenv.load(fileName: ".env");

  final appwrite = AppwriteService(
    endpoint: dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1',
    projectId: dotenv.env['APPWRITE_PROJECT_ID'] ?? 'demo',
  );
  await appwrite.ensureAnonymousSession();
  getIt.registerSingleton<AppwriteService>(appwrite);

  // Remote repositories
  getIt.registerLazySingleton<IWordRepository>(
    () => RemoteWordRepository(appwrite),
  );
  getIt.registerLazySingleton<ISentenceRepository>(
    () => RemoteSentenceRepository(appwrite),
  );
  getIt.registerLazySingleton<ITaskRepository>(
    () => RemoteTaskRepository(appwrite),
  );
  getIt.registerLazySingleton<ILanguageRepository>(
    () => RemoteLanguageRepository(appwrite),
  );
  getIt.registerLazySingleton<IUserWordStatusRepository>(
    () => RemoteUserWordStatusRepository(appwrite),
  );
  getIt.registerLazySingleton<IReadingMaterialRepository>(
    () => RemoteReadingMaterialRepository(appwrite),
  );
  getIt.registerLazySingleton<IMaterialSentenceRepository>(
    () => RemoteMaterialSentenceRepository(appwrite),
  );
  getIt.registerLazySingleton<ISentenceTaskRepository>(
    () => RemoteSentenceTaskRepository(appwrite),
  );
  getIt.registerLazySingleton<IUserSentenceTaskRepository>(
    () => RemoteUserSentenceTaskRepository(appwrite),
  );
  getIt.registerLazySingleton<ITaskTranslationRepository>(
    () => RemoteTaskTranslationRepository(appwrite),
  );
  getIt.registerLazySingleton<IUserVocabularyRepository>(
    () => RemoteUserVocabularyRepository(appwrite),
  );
  getIt.registerLazySingleton<IWordSentenceLinkRepository>(
    () => RemoteWordSentenceLinkRepository(appwrite),
  );

  // Services
  getIt.registerLazySingleton<LearningService>(
    () => LearningService(
      wordRepo: getIt<IWordRepository>(),
      sentenceRepo: getIt<ISentenceRepository>(),
      wordSentenceLinkRepo: getIt<IWordSentenceLinkRepository>(),
      userWordStatusRepo: getIt<IUserWordStatusRepository>(),
    ),
  );
  await NotificationService.init();
}