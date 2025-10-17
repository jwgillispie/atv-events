/// Subscription Management Screen - Stub Implementation
/// This is a placeholder screen for managing premium subscriptions
library;

import 'package:flutter/material.dart';
import '../widgets/upgrade_to_premium_button.dart';

class SubscriptionManagementScreen extends StatelessWidget {
  final String? userId; // Optional user ID for subscription management

  const SubscriptionManagementScreen({
    super.key,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Management'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.workspace_premium,
                size: 80,
                color: Colors.amber[700],
              ),
              const SizedBox(height: 24),
              Text(
                'Premium Subscriptions',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Premium subscription features are coming soon!\n\n'
                'Unlock advanced analytics, priority support,\n'
                'and exclusive market insights.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const UpgradeToPremiumButton(
                text: 'Learn More',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
