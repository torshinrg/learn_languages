// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:learn_languages/services/learning_service.dart';
import 'package:learn_languages/services/notification_service.dart';
import 'package:learn_languages/services/srs_service.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/di.dart';
import 'core/navigation.dart';
import 'domain/repositories/i_custom_word_repository.dart';
import 'domain/repositories/i_srs_repository.dart';
import 'domain/repositories/i_word_repository.dart';
import 'presentation/widgets/share_handler.dart';
import 'presentation/providers/custom_words_provider.dart';
import 'presentation/providers/home_provider.dart';
import 'presentation/providers/notification_settings_provider.dart';
import 'presentation/providers/review_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/study_provider.dart';
import 'presentation/providers/vocabulary_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/debug_screen.dart';
import 'presentation/screens/study_screen.dart';
import 'presentation/screens/review_screen.dart';
import 'presentation/screens/vocabulary_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/notification_settings_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  await NotificationService.init();
  tz.initializeTimeZones();

  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationSettingsProvider>(
          create: (_) => NotificationSettingsProvider(),
        ),
        Provider<LearningService>(create: (_) => getIt<LearningService>()),
        Provider<SRSService>(create: (_) => getIt<SRSService>()),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<HomeProvider>(
          create: (ctx) => HomeProvider(
            ctx.read<SRSService>(),
            ctx.read<LearningService>(),
            ctx.read<SettingsProvider>(),
          ),
        ),
        ChangeNotifierProvider<StudyProvider>(
          create: (ctx) => StudyProvider(
            ctx.read<LearningService>(),
            ctx.read<SRSService>(),
          ),
        ),
        ChangeNotifierProvider<ReviewProvider>(
          create: (ctx) => ReviewProvider(
            ctx.read<LearningService>(),
            ctx.read<SRSService>(),
          ),
        ),
        ChangeNotifierProvider<VocabularyProvider>(
          create: (ctx) => VocabularyProvider(
            ctx.read<LearningService>(),
            ctx.read<SRSService>(),
          ),
        ),
        ChangeNotifierProvider<CustomWordsProvider>(
          create: (_) => CustomWordsProvider(
            getIt<IWordRepository>(),
            getIt<ISRSRepository>(),
          ),
        ),

      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // 2. List your supported locales:
        supportedLocales: AppLocalizations.supportedLocales,
        // 3. (Optional) custom locale resolution:
        localeResolutionCallback: (locale, supported) {
          if (locale == null) return supported.first;
          for (var l in supported) {
            if (l.languageCode == locale.languageCode) return l;
          }
          return supported.first;
        },
        title: 'Learn Languages',
        theme: ThemeData( /* your theme */ ),
        // Wrap every route and widget with ShareHandler:
        builder: (ctx, child) => ShareHandler(child: child!),
        home: const HomeScreen(),
        routes: {
          '/debug': (_) => const DebugScreen(),
          '/study': (_) => const StudyScreen(),
          '/review': (_) => const ReviewScreen(),
          '/vocabulary': (_) => const VocabularyScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/reminders': (_) => const NotificationSettingsScreen(),
        },
      ),
    );
  }
}
