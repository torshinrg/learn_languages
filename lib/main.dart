// lib/main.dart

import 'package:flutter/material.dart';
import 'package:learn_languages/presentation/providers/notification_settings_provider.dart';
import 'package:learn_languages/services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'core/di.dart';
import 'core/navigation.dart';
import 'services/learning_service.dart';
import 'services/srs_service.dart';
import 'presentation/providers/home_provider.dart';
import 'presentation/providers/review_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/study_provider.dart';
import 'presentation/providers/vocabulary_provider.dart';
import 'presentation/screens/home_screen.dart';
import 'package:timezone/data/latest.dart' as tz;



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupLocator();
  await NotificationService.init();
  tz.initializeTimeZones();
  final status = await Permission.notification.status;
  print('🔑 [Main] Notification permission is $status');
  if (status.isDenied) {
    final result = await Permission.notification.request();
    print('🔑 [Main] Request result: $result');
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
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Learn Languages',
        theme: ThemeData(
          brightness: Brightness.light,                // force light mode
          scaffoldBackgroundColor: Colors.white,       // make all Scaffold backgrounds white
          primarySwatch: Colors.deepPurple,
          primaryColor: Colors.deepPurple,

          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.lightBlue,
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.lightBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.lightBlue,
              side: const BorderSide(color: Colors.lightBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          cardTheme: CardTheme(
            color: Colors.lightBlue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
