import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:learn_languages/presentation/providers/task_provider.dart';
import 'package:learn_languages/presentation/screens/tasks_screen.dart';
import 'package:learn_languages/services/learning_service.dart';
import 'package:learn_languages/services/notification_service.dart';
import 'package:learn_languages/services/srs_service.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/di.dart';
import 'core/navigation.dart';
import 'domain/repositories/i_srs_repository.dart';
import 'domain/repositories/i_task_repository.dart';
import 'domain/repositories/i_word_repository.dart';
import 'presentation/widgets/share_handler.dart';
import 'presentation/providers/custom_words_provider.dart';
import 'presentation/providers/home_provider.dart';
import 'presentation/providers/notification_settings_provider.dart';
import 'presentation/providers/review_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/study_provider.dart';
import 'presentation/providers/vocabulary_provider.dart';
import 'presentation/screens/debug_screen.dart';
import 'presentation/screens/study_screen.dart';
import 'presentation/screens/review_screen.dart';
import 'presentation/screens/vocabulary_screen.dart';
import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/notification_settings_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Global color definitions
const Color kGradientStart = Color(0xFFFF988E);
const Color kGradientEnd = Color(0xFFAC9AFF);
const Color kTextPrimary = Color(0xFF333333);
const Color kCardBackdrop = Colors.white70;
const double kPadding = 16.0;

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
  const MyApp({Key? key}) : super(key: key);

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

        ChangeNotifierProvider<StudyProvider>(
          create:
              (ctx) => StudyProvider(
                ctx.read<LearningService>(),
                ctx.read<SRSService>(),
              ),
        ),
        ChangeNotifierProvider<ReviewProvider>(
          create:
              (ctx) => ReviewProvider(
                ctx.read<LearningService>(),
                ctx.read<SRSService>(),
                ctx.read<SettingsProvider>(),
              ),
        ),
        ChangeNotifierProvider<VocabularyProvider>(
          create:
              (ctx) => VocabularyProvider(
                ctx.read<LearningService>(),
                ctx.read<SRSService>(),
              ),
        ),
        ChangeNotifierProvider<CustomWordsProvider>(
          create:
              (_) => CustomWordsProvider(
                getIt<IWordRepository>(),
                getIt<ISRSRepository>(),
              ),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create:
              (ctx) => TaskProvider(
                getIt<ITaskRepository>(),
                () => ctx.read<SettingsProvider>().locale,
              ),
        ),
        ChangeNotifierProvider<HomeProvider>(
          create:
              (ctx) => HomeProvider(
                ctx.read<SRSService>(),
                ctx.read<LearningService>(),
                ctx.read<SettingsProvider>(),
              ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (ctx, settings, _) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            locale: settings.locale, // <-- new: use provider’s locale
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            localeResolutionCallback: (locale, supported) {
              if (settings.locale != null) return settings.locale;
              if (locale == null) return supported.first;
              for (var l in supported) {
                if (l.languageCode == locale.languageCode) return l;
              }
              return supported.first;
            },
            title: 'Learn Languages',
            theme: ThemeData(
              // Base gradient applied via builder
              primaryColor: kGradientEnd,
              scaffoldBackgroundColor: Colors.transparent,
              colorScheme: ColorScheme.fromSeed(
                seedColor: kGradientEnd,
                secondary: kGradientStart,
              ),
              // Transparent AppBar, no elevation
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: kTextPrimary),
                toolbarTextStyle: TextStyle(
                  color: kTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // Text theme for readability
              textTheme: const TextTheme(
                titleLarge: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: kTextPrimary,
                ),
                bodyMedium: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: kTextPrimary,
                ),
                bodySmall: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: kTextPrimary,
                ),
              ),
              // Card styling
              cardTheme: CardTheme(
                color: kCardBackdrop,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
                shadowColor: Colors.black26,
                margin: const EdgeInsets.all(kPadding),
              ),
              // Button styles
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: kGradientEnd,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kTextPrimary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(foregroundColor: kGradientEnd),
              ),
              // Bottom nav pill
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: Colors.white70,
                selectedItemColor: kGradientEnd,
                unselectedItemColor: kTextPrimary,
                showUnselectedLabels: false,
                elevation: 0,
              ),
              // FAB styling
              floatingActionButtonTheme: const FloatingActionButtonThemeData(
                backgroundColor: kGradientEnd,
                foregroundColor: Colors.white,
                elevation: 4,
              ),
            ),
            builder:
                (ctx, child) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [kGradientStart, kGradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ShareHandler(child: child!),
                ),
            home: const InitialEntryRedirect(),
            routes: {
              '/debug': (_) => const DebugScreen(),
              '/study': (_) => const StudyScreen(),
              '/review': (_) => const ReviewScreen(),
              '/vocabulary': (_) => const VocabularyScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/reminders': (_) => const NotificationSettingsScreen(),
              '/tasks': (_) => const TaskScreen(),
            },
          );
        },
      ),
    );
  }
}
