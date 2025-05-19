// lib/presentation/widgets/flashcard.dart

import 'package:flutter/material.dart';

/// A simple card that shows [text] prominently and an optional [subText].
class Flashcard extends StatelessWidget {
  final String text;
  final String? subText;
  const Flashcard({
    super.key,
    required this.text,
    this.subText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      elevation: theme.cardTheme.elevation!,
      margin: theme.cardTheme.margin as EdgeInsets,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: theme.textTheme.headlineSmall!
                  .copyWith(color: theme.primaryColor),
              textAlign: TextAlign.center,
            ),
            if (subText != null) ...[
              const SizedBox(height: 16),
              Text(
                subText!,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
