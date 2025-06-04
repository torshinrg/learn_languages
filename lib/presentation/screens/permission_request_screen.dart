import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'onboarding_screen.dart';

class PermissionRequestScreen extends StatelessWidget {
  const PermissionRequestScreen({Key? key}) : super(key: key);

  Future<void> _requestPermissions(BuildContext context) async {
    if (await Permission.microphone.isDenied) {
      await Permission.microphone.request();
    }
    // Internet permission is granted at install time.
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
            Text(
              'This app requires Internet access to download learning content.',
            ),
            const SizedBox(height: 12),
            Text(
              'Audio permission is needed to record your voice and check pronunciation.',
            ),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: () => _requestPermissions(context),
                child: const Text('Allow'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
