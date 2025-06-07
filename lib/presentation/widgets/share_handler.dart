// lib/presentation/widgets/share_handler.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../core/navigation.dart';              // ← your global key
import '../screens/custom_words_screen.dart';

class ShareHandler extends StatefulWidget {
  final Widget child;
  const ShareHandler({required this.child, Key? key}) : super(key: key);

  @override
  _ShareHandlerState createState() => _ShareHandlerState();
}

class _ShareHandlerState extends State<ShareHandler> {
  StreamSubscription<List<SharedMediaFile>>? _sub;

  @override
  void initState() {
    super.initState();
    // Listen for shares while app is running
    _sub = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(_onShared, onError: (e) => print('Share error: $e'));
    // Handle share that launched the app
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then(_onShared)
        .catchError((e) => print('Initial share error: $e'));
  }

  void _onShared(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    debugPrint('Received share intent: '
        + files.map((f) => f.toMap().toString()).join(', '));

    for (final file in files) {
      final raw = file.path.trim();
      if (raw.isEmpty) continue;

      final cleaned = _stripUrls(raw);
      if (cleaned.isEmpty) continue;

      // ← push using the global key
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => CustomWordsScreen(initialText: cleaned),
        ),
      );
    }
    // Mark initial intent as handled so it won't be delivered again
    ReceiveSharingIntent.instance.reset();
  }

  String _stripUrls(String s) {
    final tokens = s.split(RegExp(r'\s+'));
    return tokens
        .where((t) =>
    !t.startsWith('http://') &&
        !t.startsWith('https://') &&
        !t.startsWith('www.'))
        .join(' ');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
