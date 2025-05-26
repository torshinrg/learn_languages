// lib/presentation/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../providers/notification_settings_provider.dart';
import '../providers/settings_provider.dart';
import 'notification_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _controller;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: $val words/day')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Words per day', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.dailyCount > 1
                      ? () => settings.setDailyCount(settings.dailyCount - 1)
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
                child: const Text('Save'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Study Reminders'),
              subtitle: Text(
                '${context.read<NotificationSettingsProvider>().times.length} per day',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
