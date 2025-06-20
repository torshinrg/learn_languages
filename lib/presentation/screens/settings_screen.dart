// File: lib/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:learn_languages/presentation/screens/custom_words_screen.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';
import 'notification_settings_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _controller;
  final Map<String, String> _languageNames = {
    'en': 'English',
    'es': 'Español',
    'ru': 'Русский',
  };

  @override
  void initState() {
    super.initState();
    final initial = context.read<SettingsProvider>().dailyCount;
    _controller = TextEditingController(text: initial.toString());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final updated = context.watch<SettingsProvider>().dailyCount;
    _controller.text = updated.toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final val = int.tryParse(_controller.text) ?? kDefaultDailyCount;
    context.read<SettingsProvider>().setDailyCount(val);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Saved: $val words/day')));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.words_per_day, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.dailyCount > 1
                      ? () =>
                      settings.setDailyCount(settings.dailyCount - 1)
                      : null,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      settings.setDailyCount(settings.dailyCount + 1),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: _save,
                child: Text(loc.save),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(loc.interface_language),
              subtitle: Text(_languageNames[settings.locale.languageCode]!),
              trailing: DropdownButton<String>(
                value: settings.locale.languageCode,
                items: _languageNames.entries
                    .map(
                      (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                    .toList(),
                onChanged: (newCode) {
                  if (newCode == null) return;
                  settings.setLocale(newCode);
                },
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(loc.study_reminders),
              subtitle: Text(
                '${context.read<NotificationSettingsProvider>().times.length} ${loc.per_day}',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(loc.custom_words),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomWordsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
