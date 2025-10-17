import 'package:flutter/material.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Premium Upgrade Card Widget
/// Consistent premium upgrade prompts across the app
/// Uses HiPop color palette for visual consistency
class PremiumUpgradeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? customMessage;
  final VoidCallback onUpgrade;
  final IconData icon;
  final List<String>? features;
  final bool showDismiss;
  final VoidCallback? onDismiss;

  const PremiumUpgradeCard({
    super.key,
    this.title = 'Upgrade to Premium',
    this.subtitle = 'Unlock advanced features',
    this.customMessage,
    required this.onUpgrade,
    this.icon = Icons.workspace_premium,
    this.features,
    this.showDismiss = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.premiumGold.withOpacity( 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: HiPopColors.premiumGold.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: HiPopColors.premiumGold,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: HiPopColors.premiumGold.withOpacity( 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Premium',
                              style: TextStyle(
                                color: HiPopColors.premiumGold,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDismiss)
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: HiPopColors.darkTextTertiary,
                      size: 20,
                    ),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (customMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                customMessage!,
                style: TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (features != null && features!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.darkSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: HiPopColors.darkBorder,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: features!.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: HiPopColors.successGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                color: HiPopColors.darkTextPrimary,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onUpgrade,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.premiumGold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Upgrade Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal Premium Badge Widget
class PremiumBadge extends StatelessWidget {
  final double size;
  final bool showText;

  const PremiumBadge({
    super.key,
    this.size = 20,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showText ? 8 : 4,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: HiPopColors.premiumGold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            color: Colors.white,
            size: size * 0.8,
          ),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              'Premium',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}