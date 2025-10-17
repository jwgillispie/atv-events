/// Upgrade Prompt Widget - Stub Widget
/// This is a placeholder widget for prompting users to upgrade to premium
library;

import 'package:flutter/material.dart';
import 'upgrade_to_premium_button.dart';

class UpgradePromptWidget extends StatelessWidget {
  final String title;
  final String description;
  final String? featureName;

  const UpgradePromptWidget({
    super.key,
    required this.title,
    required this.description,
    this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              size: 48,
              color: Colors.amber[700],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (featureName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Premium Feature: $featureName',
                  style: TextStyle(
                    color: Colors.amber[900],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const UpgradeToPremiumButton(),
          ],
        ),
      ),
    );
  }
}
