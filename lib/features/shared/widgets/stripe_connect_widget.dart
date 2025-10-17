import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

/// Generic Stripe Connect Widget for both Vendors and Organizers
/// Displays Stripe account connection status and allows management
///
/// Usage:
/// - Vendors: StripeConnectWidget(userType: 'vendor')
/// - Organizers: StripeConnectWidget(userType: 'organizer')
class StripeConnectWidget extends StatefulWidget {
  /// User type: 'vendor' or 'organizer'
  final String userType;

  const StripeConnectWidget({
    super.key,
    required this.userType,
  });

  @override
  State<StripeConnectWidget> createState() => _StripeConnectWidgetState();
}

class _StripeConnectWidgetState extends State<StripeConnectWidget>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Connection state
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  String? _errorMessage;

  // Stripe account data
  Map<String, dynamic>? _stripeData;
  bool _fullyVerified = false;
  bool _chargesEnabled = false;
  bool _payoutsEnabled = false;
  bool _detailsSubmitted = false;

  // Animation controller for pulse effect
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Computed properties based on user type
  String get _collectionName => '${widget.userType}_integrations';
  String get _createFunctionName => widget.userType == 'vendor'
      ? 'createStripeConnectAccount'
      : 'createOrganizerStripeConnectAccount';
  String get _checkFunctionName => widget.userType == 'vendor'
      ? 'checkStripeAccountStatus'
      : 'checkOrganizerStripeAccountStatus';
  String get _disconnectFunctionName => widget.userType == 'vendor'
      ? 'disconnectStripeAccount'
      : 'disconnectOrganizerStripeAccount';
  String get _userTypeLabel => widget.userType == 'vendor' ? 'Vendor' : 'Organizer';
  String get _paymentTypeLabel => widget.userType == 'vendor'
      ? 'preorder payments'
      : 'application payments from vendors';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.repeat(reverse: true);
    _loadStripeConnectionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStripeConnectionStatus() async {
    if (_currentUser == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'User not authenticated';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Fetch integration data
      final doc = await _firestore
          .collection(_collectionName)
          .doc(_currentUser.uid)
          .get();

      if (doc.exists && doc.data()?['stripe'] != null) {
        final stripeInfo = doc.data()!['stripe'] as Map<String, dynamic>;

        setState(() {
          _isConnected = stripeInfo['accountId'] != null;
          _stripeData = stripeInfo;
          _fullyVerified = stripeInfo['status'] == 'active';
          _chargesEnabled = stripeInfo['chargesEnabled'] ?? false;
          _payoutsEnabled = stripeInfo['payoutsEnabled'] ?? false;
          _detailsSubmitted = stripeInfo['detailsSubmitted'] ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading Stripe connection: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load connection status';
      });
    }
  }

  Future<void> _connectStripe() async {
    if (_isConnecting) return;

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🟣 [Stripe Connect] Starting $_userTypeLabel account creation...');

      // Call Cloud Function to create Connect account
      final callable = _functions.httpsCallable(_createFunctionName);
      final result = await callable.call({
        'email': _currentUser!.email,
        'businessType': 'individual',
      });

      final data = result.data as Map<String, dynamic>;
      final accountLink = data['accountLink'] as String;

      debugPrint('🟣 [Stripe Connect] Launching onboarding URL...');

      // Launch Stripe onboarding
      final launched = await launchUrl(
        Uri.parse(accountLink),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not launch Stripe onboarding');
      }

      // Show connection in progress dialog
      if (mounted) {
        _showConnectionInProgressDialog();
      }

    } catch (e) {
      debugPrint('❌ [Stripe Connect] Error: $e');
      setState(() {
        _errorMessage = 'Failed to start Stripe connection: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _refreshStatus() async {
    if (_currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('🟣 [Stripe Connect] Refreshing account status...');

      final callable = _functions.httpsCallable(_checkFunctionName);
      final result = await callable.call();

      final data = result.data as Map<String, dynamic>;

      if (data['connected'] == true) {
        setState(() {
          _isConnected = true;
          _fullyVerified = data['fullyVerified'] ?? false;
          _chargesEnabled = data['chargesEnabled'] ?? false;
          _payoutsEnabled = data['payoutsEnabled'] ?? false;
          _detailsSubmitted = data['detailsSubmitted'] ?? false;
        });

        // Reload from Firestore to get updated data
        await _loadStripeConnectionStatus();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Status updated'),
              ],
            ),
            backgroundColor: HiPopColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

    } catch (e) {
      debugPrint('❌ [Stripe Connect] Error refreshing status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnectStripe() async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: HiPopColors.errorPlum.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: HiPopColors.warningAmber,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Disconnect Stripe?',
              style: TextStyle(
                color: HiPopColors.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'This will disconnect your Stripe account and you won\'t be able to ${widget.userType == 'vendor' ? 'accept preorder payments' : 'receive application payments'} until you reconnect.',
          style: const TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.errorPlum,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isDisconnecting = true;
      _errorMessage = null;
    });

    try {
      final callable = _functions.httpsCallable(_disconnectFunctionName);
      await callable.call();

      setState(() {
        _isConnected = false;
        _stripeData = null;
        _fullyVerified = false;
        _chargesEnabled = false;
        _payoutsEnabled = false;
        _detailsSubmitted = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Stripe account disconnected'),
              ],
            ),
            backgroundColor: HiPopColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to disconnect: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isDisconnecting = false;
      });
    }
  }

  void _showConnectionInProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF635BFF)), // Stripe purple
            ),
            SizedBox(height: 24),
            Text(
              'Setting up Stripe Connect',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Please complete onboarding in your browser',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadStripeConnectionStatus(); // Refresh status
            },
            child: const Text('Check Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null && !_isConnected) {
      return _buildErrorState();
    }

    return _isConnected ? _buildConnectedState() : _buildDisconnectedState();
  }

  Widget _buildLoadingState() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF635BFF).withValues(alpha: 0.5),
              ),
              backgroundColor: HiPopColors.darkSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading Stripe connection...',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HiPopColors.errorPlum.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: HiPopColors.errorPlum,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Connection error',
              style: const TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadStripeConnectionStatus,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF635BFF),
                side: const BorderSide(color: Color(0xFF635BFF)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedState() {
    final statusColor = _fullyVerified
        ? HiPopColors.successGreen
        : _detailsSubmitted
            ? HiPopColors.warningAmber
            : HiPopColors.infoBlueGray;

    final statusText = _fullyVerified
        ? 'Fully Verified'
        : _detailsSubmitted
            ? 'Verification Pending'
            : 'Setup Incomplete';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _fullyVerified ? 1.0 : _pulseAnimation.value,
          child: Card(
            color: HiPopColors.darkSurface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: statusColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF635BFF), // Stripe purple
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF635BFF).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.payments,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Stripe Connected',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: HiPopColors.darkTextPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _stripeData?['businessName'] ?? 'Stripe Account',
                              style: const TextStyle(
                                fontSize: 14,
                                color: HiPopColors.darkTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _showConnectionMenu,
                        icon: const Icon(
                          Icons.more_vert,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Status info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkSurfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.verified_user,
                          'Status',
                          statusText,
                          valueColor: statusColor,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.credit_card,
                          widget.userType == 'vendor' ? 'Accept Payments' : 'Receive Payments',
                          _chargesEnabled ? 'Enabled' : 'Disabled',
                          valueColor: _chargesEnabled ? HiPopColors.successGreen : HiPopColors.errorPlum,
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow(
                          Icons.account_balance,
                          'Payouts',
                          _payoutsEnabled ? 'Enabled' : 'Disabled',
                          valueColor: _payoutsEnabled ? HiPopColors.successGreen : HiPopColors.errorPlum,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _refreshStatus,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Refresh Status'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF635BFF),
                            side: BorderSide(
                              color: const Color(0xFF635BFF).withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isDisconnecting ? null : _disconnectStripe,
                          icon: _isDisconnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      HiPopColors.errorPlum,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.link_off, size: 18),
                          label: Text(_isDisconnecting ? 'Disconnecting...' : 'Disconnect'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: HiPopColors.errorPlum,
                            side: BorderSide(
                              color: HiPopColors.errorPlum.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedState() {
    return Card(
      color: HiPopColors.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HiPopColors.darkBorder,
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.payments_outlined,
                      color: HiPopColors.darkTextTertiary,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connect Stripe',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.userType == 'vendor'
                            ? 'Accept preorder payments'
                            : 'Receive application payments',
                        style: const TextStyle(
                          fontSize: 14,
                          color: HiPopColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Benefits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF635BFF).withValues(alpha: 0.05),
                    const Color(0xFF635BFF).withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: Color(0xFF635BFF),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Benefits',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF635BFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...widget.userType == 'vendor' ? [
                    _buildBenefitItem('Accept preorder payments'),
                    _buildBenefitItem('Automatic payouts'),
                    _buildBenefitItem('Low platform fees (2.5-3.5%)'),
                    _buildBenefitItem('Secure Stripe processing'),
                  ] : [
                    _buildBenefitItem('Receive vendor application payments'),
                    _buildBenefitItem('Automatic transfers (90% of fees)'),
                    _buildBenefitItem('Platform handles payment processing'),
                    _buildBenefitItem('Secure Stripe Connect'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Connect button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connectStripe,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Icon(Icons.link),
                label: Text(
                  _isConnecting ? 'Connecting...' : 'Connect Stripe Account',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF635BFF), // Stripe purple
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Privacy note
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: HiPopColors.darkTextTertiary,
                ),
                SizedBox(width: 4),
                Text(
                  'Secure Stripe Express connection',
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: HiPopColors.darkTextTertiary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? HiPopColors.darkTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: HiPopColors.successGreen,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: HiPopColors.darkTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: HiPopColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Color(0xFF635BFF)),
              title: const Text('Refresh Status'),
              subtitle: const Text('Check latest verification status'),
              onTap: () {
                Navigator.pop(context);
                _refreshStatus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: HiPopColors.darkTextSecondary),
              title: const Text('Help'),
              subtitle: const Text('Learn about Stripe Connect'),
              onTap: () {
                Navigator.pop(context);
                _showHelpDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_off, color: HiPopColors.errorPlum),
              title: const Text(
                'Disconnect',
                style: TextStyle(color: HiPopColors.errorPlum),
              ),
              subtitle: const Text('Remove Stripe connection'),
              onTap: () {
                Navigator.pop(context);
                _disconnectStripe();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.help_outline,
              color: Color(0xFF635BFF),
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Stripe Connect',
              style: TextStyle(
                color: HiPopColors.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How it works',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.userType == 'vendor'
                    ? 'Connect your Stripe account to accept preorder payments. Stripe handles secure payment processing and automatically pays you out to your bank account.'
                    : 'Connect your Stripe account to receive vendor application payments. When vendors pay application fees, 90% is automatically transferred to your bank account.',
                style: const TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Platform Fees',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.userType == 'vendor'
                    ? '• Premium vendors: 3.5% platform fee\n'
                      '• Standard vendors: 2.5% platform fee\n'
                      '• Stripe fees: ~2.9% + \$0.30 (charged to buyer)'
                    : '• Platform fee: 10% of application fees\n'
                      '• You receive: 90% of all application fees\n'
                      '• Automatic transfers to your bank account',
                style: const TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Privacy & Security',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stripe Express provides secure, compliant payment processing. Your bank details are safely stored with Stripe, not HiPop.',
                style: TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
