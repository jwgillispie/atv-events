/// Upgrade to Premium Button - Stub Widget
/// This is a placeholder widget for premium upgrade functionality
library;

import 'package:flutter/material.dart';

class UpgradeToPremiumButton extends StatelessWidget {
  final String? text;
  final VoidCallback? onPressed;
  final bool isCompact;
  final String? userType; // Optional user type for customization
  final VoidCallback? onSuccess; // Add onSuccess parameter for compatibility

  const UpgradeToPremiumButton({
    super.key,
    this.text,
    this.onPressed,
    this.isCompact = false,
    this.userType,
    this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium features coming soon!'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      icon: const Icon(Icons.star, size: 18),
      label: Text(text ?? 'Upgrade to Premium'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
        padding: isCompact
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }
}
