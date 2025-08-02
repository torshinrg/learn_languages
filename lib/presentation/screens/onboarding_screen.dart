// File: lib/presentation/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/app_language.dart';
import '../providers/settings_provider.dart';
import '../providers/home_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/constants.dart';
import 'permission_request_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedNative; // код родного языка
  final List<String> _selectedLearning = []; // список кодов изучаемых языков
  final TextEditingController _dailyCountController = TextEditingController(
    text: '',
  );


  @override
  void initState() {
    super.initState();
    // Если ранее уже где-то был выбран dailyCount, подставляем его
    final settings = context.read<SettingsProvider>();
    _dailyCountController.text = settings.dailyCount.toString();
  }

  @override
  void dispose() {
    _dailyCountController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final loc = AppLocalizations.of(context)!;
    if (_selectedNative == null || _selectedLearning.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.chooseLanguagesError)),
      );
      return;
    }
    final count =
        int.tryParse(_dailyCountController.text) ?? kDefaultDailyCount;

    // Сохраняем всё в SettingsProvider
    final settings = context.read<SettingsProvider>();
    await settings.setNativeLanguage(_selectedNative!);
    await settings.setLearningLanguages(_selectedLearning);
    await settings.setDailyCount(count);
    await context.read<HomeProvider>().refresh();

    // After saving, request permissions on mobile; go straight to home on web
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => kIsWeb
            ? const HomeScreen()
            : const PermissionRequestScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final allLanguages = AppLanguage.values;


    return Scaffold(
      appBar: AppBar(title: Text(loc.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                loc.chooseNativeLanguage,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    allLanguages.map((lang) {
                      final code = lang.code;
                      final name = lang.displayName;
                      final selected = _selectedNative == code;
                      return ChoiceChip(
                        label: Text(name),
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _selectedNative = code;
                            // Если вдруг в списке изучаемых был родной язык, уберем его
                            if (_selectedLearning.contains(code)) {
                              _selectedLearning.remove(code);
                            }
                          });
                          // Обновляем язык интерфейса сразу после выбора
                          context.read<SettingsProvider>().setLocale(code);
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                loc.chooseLearningLanguages,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    allLanguages.map((lang) {
                      final code = lang.code;
                      final name = lang.displayName;
                      final isDisabled = _selectedNative == code;
                      final isSelected = _selectedLearning.contains(code);
                      return FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected:
                            isDisabled
                                ? null
                                : (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedLearning.add(code);
                                    } else {
                                      _selectedLearning.remove(code);
                                    }
                                  });
                                },
                        selectedColor: Colors.blue.shade100,
                        disabledColor: Colors.grey.shade200,
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                loc.chooseDailyWordCount,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      final current =
                          int.tryParse(_dailyCountController.text) ?? 1;
                      if (current > 1) {
                        _dailyCountController.text = (current - 1).toString();
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _dailyCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      final current =
                          int.tryParse(_dailyCountController.text) ?? 0;
                      _dailyCountController.text = (current + 1).toString();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () => _onSubmit(),
                  child: Text(loc.getStarted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InitialEntryRedirect extends StatefulWidget {
  const InitialEntryRedirect({super.key});

  @override
  State<InitialEntryRedirect> createState() => _InitialEntryRedirectState();
}

class _InitialEntryRedirectState extends State<InitialEntryRedirect> {
  @override
  void initState() {
    super.initState();
    // Wait until this route becomes the top-most route (e.g. after a share
    // intent might push another screen) before deciding where to navigate.
    Future.microtask(_checkAndDecide);
  }

  Future<void> _checkAndDecide() async {
    // If another route is currently on top (for example, the CustomWordsScreen
    // launched from a share intent), postpone the decision until this route
    // becomes active again.
    if (!mounted) return;
    final modal = ModalRoute.of(context);
    if (modal != null && !modal.isCurrent) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _checkAndDecide();
    }
    await _decide();
  }

  Future<void> _decide() async {
    final settings = context.read<SettingsProvider>();

    // 1) Still loading SharedPrefs? wait
    if (!settings.isLoaded) {
      await Future.delayed(const Duration(milliseconds: 100));
      return _decide();
    }

    // 2) Haven’t chosen languages yet?
    if (settings.learningLanguageCodes.isEmpty ||
        settings.nativeLanguageCode == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
      return;
    }

    // 3) Missing mic or notification permission? Skip checks on web.
    if (!kIsWeb &&
        (await Permission.microphone.isDenied ||
            await Permission.notification.isDenied)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PermissionRequestScreen()),
      );
      return;
    }

    // 4) Everything’s good → Home
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Пустой заглушечный экран, сразу переходящий на реальный HomeScreen.
/// Можно поменять на любой, более подходящий вашим маршрутам.
class HomeScreenPlaceholder extends StatelessWidget {
  const HomeScreenPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    // Ждём пару миллисекунд, чтобы дать событию build отработать
    Future.microtask(() {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
