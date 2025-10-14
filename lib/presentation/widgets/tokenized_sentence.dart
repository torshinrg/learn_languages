import 'package:flutter/material.dart';

import '../../domain/entities/user_word_status.dart';
import '../providers/reader_provider.dart';

class TokenizedSentence extends StatelessWidget {
  const TokenizedSentence({
    super.key,
    required this.data,
    required this.onTokenTap,
  });

  final SentenceViewData data;
  final ValueChanged<SentenceTokenData> onTokenTap;

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        Theme.of(context).textTheme.headlineSmall ??
        const TextStyle(fontSize: 22);

    if (data.tokens.isEmpty) {
      final fallback = data.sentence.sentence?.content ?? '';
      return Text(fallback, style: baseStyle, textAlign: TextAlign.center);
    }

    final spans = <InlineSpan>[];
    for (var i = 0; i < data.tokens.length; i++) {
      final token = data.tokens[i];
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onTokenTap(token),
            child: Text(
              token.text,
              style: _styleForStatus(context, baseStyle, token.status),
            ),
          ),
        ),
      );
      if (i < data.tokens.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  TextStyle _styleForStatus(
    BuildContext context,
    TextStyle base,
    WordStatus? status,
  ) {
    switch (status) {
      case WordStatus.known:
        return base.copyWith(
          color: Colors.green.shade800,
          backgroundColor: Colors.green.shade100,
        );
      case WordStatus.inProgress:
        return base.copyWith(
          color: Colors.orange.shade800,
          backgroundColor: Colors.orange.shade100,
        );
      case WordStatus.New:
        return base.copyWith(
          color: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withOpacity(0.12),
        );
      default:
        return base;
    }
  }
}
