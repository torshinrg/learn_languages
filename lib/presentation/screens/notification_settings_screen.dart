// File: lib/presentation/screens/notification_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_settings_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationSettingsProvider>();
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title:  Text(loc.reminder_settings)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: vm.times.length + 1,
        itemBuilder: (ctx, i) {
          if (i == vm.times.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label:  Text(loc.add_reminder),
                onPressed: () => _pickTime(context, null, vm),
              ),
            );
          }
          final t = vm.times[i];
          return ListTile(
            title: Text('${t.format(context)}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => vm.removeTime(i),
            ),
            onTap: () => _pickTime(context, t, vm, index: i),
          );
        },
      ),
    );
  }

  Future<void> _pickTime(
      BuildContext context,
      TimeOfDay? existing,
      NotificationSettingsProvider vm, {
        int? index,
      }) async {
    final loc = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final initial = existing ?? TimeOfDay.fromDateTime(now);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;

    if (index == null) {
      await vm.addTime(picked);
      final scheduledLocal = DateTime(
        now.year,
        now.month,
        now.day,
        picked.hour,
        picked.minute,
      );
      final nextFire = scheduledLocal.isBefore(now)
          ? scheduledLocal.add(const Duration(days: 1))
          : scheduledLocal;
      final formattedNow = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final formattedNext = DateFormat('yyyy-MM-dd HH:mm').format(nextFire);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.reminderSet(picked.format(context), formattedNow, formattedNext),
          ),
        ),
      );
    } else {
      await vm.updateTime(index, picked);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text( loc.reminderUpdated(picked.format(context)),),
        ),
      );
    }
  }
}