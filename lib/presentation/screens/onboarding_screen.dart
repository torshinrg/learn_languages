// File: lib/presentation/screens/onboarding_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_language.dart';
import '../providers/settings_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'permission_request_screen.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedNative; // код родного языка
  List<String> _selectedLearning = []; // список кодов изучаемых языков
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

  void _onSubmit() {
    if (_selectedNative == null || _selectedLearning.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please choose native and learning languages.')),
      );
      return;
    }
    final count =
        int.tryParse(_dailyCountController.text) ??
        SettingsProvider.kDailyCountKey as int;

    // Сохраняем всё в SettingsProvider
    final settings = context.read<SettingsProvider>();
    settings.setNativeLanguage(_selectedNative!);
    settings.setLearningLanguages(_selectedLearning);
    settings.setDailyCount(count);

    // After saving, show permission request screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const PermissionRequestScreen()),
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
                '1. Choose your native language',
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
                        },
                      );
                    }).toList(),
              ),
              const SizedBox(height: 24),
              Text(
                '2. Choose languages to learn',
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
                '3. How many words per day?',
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
                  onPressed: _onSubmit,
                  child: const Text('Get Started'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Этот виджет просто перенаправляет на HomeScreen или, если он ещё не выбран,
/// вновь открывает Onboarding. Нам нужно, чтобы можно было сделать pushReplacement.
class InitialEntryRedirect extends StatelessWidget {
  const InitialEntryRedirect({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (!settings.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Если языки не выбраны, открываем Onboarding:
    if (settings.learningLanguageCodes.isEmpty ||
        settings.nativeLanguageCode == null) {
      return const OnboardingScreen();
    }
    // Иначе – HomeScreen
    return const HomeScreenPlaceholder();
  }
}

/// Пустой заглушечный экран, сразу переходящий на реальный HomeScreen.
/// Можно поменять на любой, более подходящий вашим маршрутам.
class HomeScreenPlaceholder extends StatelessWidget {
  const HomeScreenPlaceholder({Key? key}) : super(key: key);

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
