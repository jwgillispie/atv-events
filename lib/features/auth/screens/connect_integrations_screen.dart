import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'dart:math';

/// Optional screen to connect Square/Shopify after signup
/// Can be skipped and shown again later
class ConnectIntegrationsScreen extends StatefulWidget {
  final String userType;

  const ConnectIntegrationsScreen({
    super.key,
    required this.userType,
  });

  @override
  State<ConnectIntegrationsScreen> createState() => _ConnectIntegrationsScreenState();
}

class _ConnectIntegrationsScreenState extends State<ConnectIntegrationsScreen> {
  bool _isConnectingSquare = false;

  @override
  Widget build(BuildContext context) {
    final isVendor = widget.userType == 'vendor';
    final colorScheme = isVendor
        ? HiPopColors.vendorAccent
        : HiPopColors.organizerAccent;

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Skip button in top right
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => _skip(context),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 16,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_business_outlined,
                          size: 60,
                          color: colorScheme,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        isVendor
                            ? 'Connect Your POS System'
                            : 'Optional: Connect Your Tools',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        isVendor
                            ? 'Track sales automatically and unlock powerful analytics'
                            : 'Streamline your market management workflow',
                        style: const TextStyle(
                          fontSize: 16,
                          color: HiPopColors.darkTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // Integration cards
                      _buildSquareCard(context, colorScheme),
                      const SizedBox(height: 16),
                      _buildShopifyCard(context, colorScheme),
                      const SizedBox(height: 32),

                      // Benefits section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: HiPopColors.darkSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.withAlpha(50),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: colorScheme,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Why connect?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: HiPopColors.darkTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (isVendor) ...[
                              _buildBenefit(
                                Icons.analytics_outlined,
                                'Automatic Sales Tracking',
                                'No manual entry needed',
                              ),
                              _buildBenefit(
                                Icons.insights_outlined,
                                'Revenue Analytics',
                                'See which popups perform best',
                              ),
                              _buildBenefit(
                                Icons.trending_up,
                                'Growth Insights',
                                'Data-driven recommendations',
                              ),
                              _buildBenefit(
                                Icons.shield_outlined,
                                'Secure & Private',
                                'OAuth 2.0 encrypted connection',
                              ),
                            ] else ...[
                              _buildBenefit(
                                Icons.people_outline,
                                'Better Vendor Relations',
                                'See vendor sales performance',
                              ),
                              _buildBenefit(
                                Icons.bar_chart,
                                'Market Analytics',
                                'Track overall market success',
                              ),
                              _buildBenefit(
                                Icons.lightbulb_outline,
                                'Smart Recommendations',
                                'Optimize future events',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom action
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _skip(context),
                  child: const Text(
                    'I\'ll do this later',
                    style: TextStyle(
                      fontSize: 15,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquareCard(BuildContext context, Color colorScheme) {
    return InkWell(
      onTap: () => _connectSquare(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HiPopColors.darkBorder),
        ),
        child: Row(
          children: [
            // Square logo placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'sq',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Square POS',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Most popular for vendors',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(
              Icons.arrow_forward_ios,
              color: HiPopColors.darkTextSecondary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopifyCard(BuildContext context, Color colorScheme) {
    return InkWell(
      onTap: () => _connectShopify(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HiPopColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HiPopColors.darkBorder),
        ),
        child: Row(
          children: [
            // Shopify logo placeholder
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF96BF48),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shopping_bag,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // Info
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shopify',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Coming soon',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: HiPopColors.accentMauve.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Soon',
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.accentMauve,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: HiPopColors.successGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connectSquare(BuildContext context) async {
    if (_isConnectingSquare) return;

    setState(() {
      _isConnectingSquare = true;
    });

    try {
      debugPrint('🟦 [Square OAuth] Starting Square OAuth flow...');

      // Generate secure random state for CSRF protection
      final state = _generateRandomState();
      debugPrint('🟦 [Square OAuth] Generated state: $state');

      // Square OAuth URL with your Application ID
      const squareAppId = 'sq0idp-tWeM42bRInslW_1KBfEYMQ';
      final redirectUri = Uri.encodeComponent('https://hipopmarkets.web.app/oauth/square/callback');

      final authUrl = Uri.parse(
        'https://connect.squareup.com/oauth2/authorize'
        '?client_id=$squareAppId'
        '&scope=MERCHANT_PROFILE_READ+PAYMENTS_READ+PAYMENTS_WRITE'
        '&session=false'
        '&state=$state'
      );

      debugPrint('🟦 [Square OAuth] Launching URL: $authUrl');

      // Launch Square OAuth in browser
      final launched = await launchUrl(
        authUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not launch Square authorization page');
      }

      debugPrint('✅ [Square OAuth] Browser launched successfully');

      // Show info dialog
      if (context.mounted) {
        _showSquareOAuthInfo(context);
      }

    } catch (e) {
      debugPrint('❌ [Square OAuth] Error: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start Square connection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingSquare = false;
        });
      }
    }
  }

  void _showSquareOAuthInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: const Text(
          'Connect with Square',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: const Text(
          'A browser window has opened. Please log in to your Square account and authorize HiPop Markets.\n\n'
          'After authorization, you\'ll be redirected back to complete setup.',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/auth/complete-profile');
            },
            child: const Text('Continue to Profile'),
          ),
        ],
      ),
    );
  }

  String _generateRandomState() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return values.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  void _connectShopify(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Shopify integration coming soon!'),
        backgroundColor: HiPopColors.accentMauve,
      ),
    );
  }

  void _skip(BuildContext context) {
    // Navigate to profile completion
    context.go('/auth/complete-profile');
  }
}
