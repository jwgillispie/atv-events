import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Screen that handles the OAuth callback from Square
/// Exchanges authorization code for access token via Cloud Function
class SquareOAuthCallbackScreen extends StatefulWidget {
  final String? code;
  final String? state;
  final String? error;

  const SquareOAuthCallbackScreen({
    super.key,
    this.code,
    this.state,
    this.error,
  });

  @override
  State<SquareOAuthCallbackScreen> createState() => _SquareOAuthCallbackScreenState();
}

class _SquareOAuthCallbackScreenState extends State<SquareOAuthCallbackScreen> {
  bool _isProcessing = true;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _processCallback();
  }

  Future<void> _processCallback() async {
    debugPrint('🟦 [Square OAuth Callback] Processing callback...');
    debugPrint('🟦 [Square OAuth Callback] Code: ${widget.code?.substring(0, 10)}...');
    debugPrint('🟦 [Square OAuth Callback] State: ${widget.state}');
    debugPrint('🟦 [Square OAuth Callback] Error: ${widget.error}');

    // Check for OAuth error
    if (widget.error != null) {
      debugPrint('❌ [Square OAuth Callback] OAuth error: ${widget.error}');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Authorization failed: ${widget.error}';
      });
      return;
    }

    // Validate required parameters
    if (widget.code == null || widget.code!.isEmpty) {
      debugPrint('❌ [Square OAuth Callback] Missing authorization code');
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Invalid callback: missing authorization code';
      });
      return;
    }

    try {
      debugPrint('🟦 [Square OAuth Callback] Calling exchangeSquareToken function...');

      // Call Cloud Function to exchange code for tokens
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('exchangeSquareToken');

      final result = await callable.call({
        'code': widget.code,
        'state': widget.state,
      });

      final data = result.data as Map<String, dynamic>;
      debugPrint('✅ [Square OAuth Callback] Token exchange successful');
      debugPrint('🟦 [Square OAuth Callback] Merchant ID: ${data['merchantId']}');
      debugPrint('🟦 [Square OAuth Callback] Business: ${data['businessName']}');

      setState(() {
        _isProcessing = false;
        _successMessage = 'Square account connected successfully!';
      });

      // Navigate to profile completion after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        context.go('/auth/complete-profile');
      }

    } catch (e) {
      debugPrint('❌ [Square OAuth Callback] Error exchanging token: $e');

      setState(() {
        _isProcessing = false;
        _errorMessage = 'Failed to connect Square account: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                if (_isProcessing) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HiPopColors.vendorAccent.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.vendorAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connecting to Square...',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please wait while we complete the connection',
                    style: TextStyle(
                      fontSize: 15,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connection Failed',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => context.go('/auth/complete-profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.vendorAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Continue to Profile'),
                  ),
                ] else if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: HiPopColors.successGreen.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      size: 60,
                      color: HiPopColors.successGreen,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Connected!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _successMessage!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Redirecting...',
                    style: TextStyle(
                      fontSize: 13,
                      color: HiPopColors.darkTextTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
