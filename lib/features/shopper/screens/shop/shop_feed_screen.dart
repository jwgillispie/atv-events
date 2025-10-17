// TODO: Removed for ATV MVP - Shop feed screen stub
import 'package:flutter/material.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Shop feed screen showing available products
/// Stub implementation for ATV Events MVP
class ShopFeedScreen extends StatelessWidget {
  const ShopFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ATVColors.darkBackground,
      appBar: AppBar(
        title: const Text('Shop'),
        backgroundColor: ATVColors.darkSurface,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 64,
                color: ATVColors.darkTextTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Shop Coming Soon',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ATVColors.darkTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Product shopping features will be available in a future update',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ATVColors.darkTextSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
