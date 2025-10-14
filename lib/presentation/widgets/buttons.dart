// lib/presentation/widgets/buttons.dart

import 'package:flutter/material.dart';

/// Button variants supported by [FullWidthButton].
enum ButtonVariant { primary, secondary }

/// A full-width button with optional variant styling.
class FullWidthButton extends StatelessWidget {
  const FullWidthButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : variant = ButtonVariant.primary;

  const FullWidthButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
  }) : variant = ButtonVariant.secondary;

  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final buttonChild = Text(label);
    final button = variant == ButtonVariant.primary
        ? ElevatedButton(onPressed: onPressed, child: buttonChild)
        : OutlinedButton(onPressed: onPressed, child: buttonChild);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: button,
    );
  }
}
