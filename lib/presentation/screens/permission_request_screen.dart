import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'onboarding_screen.dart';
import '../providers/notification_settings_provider.dart';
import 'package:learn_languages/services/notification_service.dart';

class PermissionRequestScreen extends StatelessWidget {
  const PermissionRequestScreen({super.key});

  Future<void> _requestPermissions(BuildContext context) async {
    if (kIsWeb) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const InitialEntryRedirect()),
      );
      return;
    }
    // 1) Initialize notifications (creates channel + may ask on Android13+)
    await NotificationService.init();

    // 2) Ask for notification permission if still denied
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 3) Ask for microphone permission (for your speech features)
    if (await Permission.microphone.isDenied) {
      await Permission.microphone.request();
    }

    // 4) Re-schedule any saved reminders
    final times = context.read<NotificationSettingsProvider>().times;
    final notifService = GetIt.I<NotificationService>();
    await notifService.scheduleDailyNotifications(times);

    // 5) Finally enter the app
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InitialEntryRedirect()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.appTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.notification_access),

            const SizedBox(height: 12),
            Text(loc.record_access),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () => _requestPermissions(context),
                child: Text(loc.allow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
