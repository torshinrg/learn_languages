import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:learn_languages/data/remote/appwrite_service.dart';
import 'package:learn_languages/core/local_db.dart';
import 'package:learn_languages/data/local/local_user_word_status_repo.dart';
import 'package:learn_languages/data/user_word_status/adaptive_user_word_status_repo.dart';
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
import 'package:learn_languages/data/local/reading_progress_store.dart';
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
import 'package:learn_languages/services/native_dictionary_service.dart';
import 'package:learn_languages/services/translation_service.dart';
import 'package:learn_languages/core/app_config.dart';
import 'package:learn_languages/core/appwrite_schema_probe.dart';

final GetIt getIt = GetIt.instance;

Future<void> setupLocator() async {
  await dotenv.load(fileName: ".env");

  final translatorConfig = TranslatorConfig(
    baseUrl: dotenv.env['TRANSLATOR_BASE_URL'] ?? '',
    apiKey: dotenv.env['TRANSLATOR_API_KEY'],
  );
  final appConfig = AppConfig(translator: translatorConfig);
  getIt.registerSingleton<AppConfig>(appConfig);

  if (!translatorConfig.isEnabled) {
    debugPrint(
      '[Translation] disabled: missing TRANSLATOR_BASE_URL environment variable.',
    );
  } else if (!translatorConfig.hasApiKey) {
    debugPrint(
      '[Translation] warning: TRANSLATOR_API_KEY not set; assuming public access.',
    );
  }

  final appwrite = AppwriteService(
    endpoint: dotenv.env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1',
    projectId: dotenv.env['APPWRITE_PROJECT_ID'] ?? 'demo',
  );
  await appwrite.ensureAnonymousSession();
  getIt.registerSingleton<AppwriteService>(appwrite);

  // Local DB for unauthenticated user data
  final userLocalDb = await openUserLocalDb();

  getIt.registerLazySingleton<ReadingProgressStore>(
    () => ReadingProgressStore(),
  );

  // Probe public schema and record field names for this session
  await AppwriteSchemaProbe(appwrite).run();

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
  // User-specific repo uses adaptive routing: local when anonymous, remote when logged in
  getIt.registerLazySingleton<IUserWordStatusRepository>(() {
    final remote = RemoteUserWordStatusRepository(appwrite);
    final local = LocalUserWordStatusRepository(userLocalDb);
    return AdaptiveUserWordStatusRepository(
      appwrite: appwrite,
      remote: remote,
      local: local,
    );
  });
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

  appwrite.init(
    wordRepository: getIt<IWordRepository>(),
    userWordStatusRepository: getIt<IUserWordStatusRepository>(),
  );

  // Services
  getIt.registerLazySingleton<LearningService>(
    () => LearningService(
      wordRepo: getIt<IWordRepository>(),
      sentenceRepo: getIt<ISentenceRepository>(),
      wordSentenceLinkRepo: getIt<IWordSentenceLinkRepository>(),
      userWordStatusRepo: getIt<IUserWordStatusRepository>(),
      languageRepo: getIt<ILanguageRepository>(),
    ),
  );
  getIt.registerLazySingleton<TranslationService>(
    () => TranslationService(config: appConfig.translator),
  );
  getIt.registerLazySingleton<NativeDictionaryService>(
    () => NativeDictionaryService(
      translationService: getIt<TranslationService>(),
    ),
  );
  await NotificationService.init();
}
