// lib/presentation/widgets/buttons.dart

import 'package:flutter/material.dart';

/// A full-width, fixed-height primary button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;  // allow null to disable
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,      // can be null
        child: Text(label),
      ),
    );
  }
}

/// A full-width, fixed-height secondary (outlined) button.
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
