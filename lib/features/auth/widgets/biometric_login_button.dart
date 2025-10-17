import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../services/biometric_auth_service.dart';

/// Premium biometric authentication button for HiPop marketplace
/// Provides Face ID/Touch ID login with sophisticated animations and error handling
class BiometricLoginButton extends StatefulWidget {
  final String userType;
  final String? email;
  final VoidCallback? onSuccess;
  final VoidCallback? onError;
  final bool showQuickAccess;

  const BiometricLoginButton({
    super.key,
    required this.userType,
    this.email,
    this.onSuccess,
    this.onError,
    this.showQuickAccess = false,
  });

  @override
  State<BiometricLoginButton> createState() => _BiometricLoginButtonState();
}

class _BiometricLoginButtonState extends State<BiometricLoginButton>
    with SingleTickerProviderStateMixin {
  final BiometricAuthService _biometricService = BiometricAuthService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  bool _isAuthenticating = false;
  BiometricAvailability? _availability;
  bool _hasStoredCredentials = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkBiometricAvailability();
  }
  
  @override
  void didUpdateWidget(BiometricLoginButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check availability if email changes
    if (oldWidget.email != widget.email) {
      _checkBiometricAvailability();
    }
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  Future<void> _checkBiometricAvailability() async {
    final availability = await _biometricService.checkBiometricAvailability();
    
    // Check credentials based on email if provided
    bool hasCredentials = false;
    if (widget.email != null && widget.email!.isNotEmpty) {
      hasCredentials = await _biometricService.hasCredentialsForEmail(widget.email!);
    } else {
      // Fallback to legacy check
      hasCredentials = await _biometricService.hasStoredCredentials();
    }
    
    if (mounted) {
      setState(() {
        _availability = availability;
        _hasStoredCredentials = hasCredentials;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleBiometricAuth() async {
    if (_isAuthenticating) return;
    
    setState(() => _isAuthenticating = true);
    
    // Add haptic feedback for premium feel
    HapticFeedback.lightImpact();
    
    try {
      // First authenticate with biometrics
      final authResult = await _biometricService.authenticateWithBiometrics(
        reason: _getAuthReason(),
      );
      
      if (!authResult.success) {
        _handleAuthError(authResult);
        return;
      }
      
      // Get stored credentials based on email
      UserCredentials? credentials;
      if (widget.email != null && widget.email!.isNotEmpty) {
        credentials = await _biometricService.getStoredCredentials(widget.email!);
      } else {
        // Fallback to legacy method
        credentials = await _biometricService.getCredentials();
      }
      
      if (credentials == null) {
        _showSnackBar(
          'No saved credentials found. Please log in with your email and password first.',
          isError: true,
        );
        return;
      }
      
      // Authenticate with stored credentials
      if (mounted) {
        context.read<AuthBloc>().add(LoginEvent(
          email: credentials.email,
          password: credentials.password,
        ));
      }
      
      // Success haptic feedback
      HapticFeedback.mediumImpact();
      widget.onSuccess?.call();
      
    } catch (e) {
      _showSnackBar('Authentication failed: ${e.toString()}', isError: true);
      widget.onError?.call();
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  String _getAuthReason() {
    switch (widget.userType) {
      case 'vendor':
        return 'Authenticate to access your vendor dashboard';
      case 'market_organizer':
        return 'Authenticate to manage your markets';
      case 'shopper':
        return 'Authenticate to continue shopping at HiPop';
      default:
        return 'Authenticate to access HiPop';
    }
  }

  void _handleAuthError(BiometricAuthResult result) {
    String message = result.error ?? 'Authentication failed';
    
    switch (result.errorType) {
      case BiometricErrorType.notEnrolled:
        message = 'Please set up Face ID or Touch ID in your device settings first';
        break;
      case BiometricErrorType.lockedOut:
        message = 'Too many failed attempts. Please try again later or use your password';
        break;
      case BiometricErrorType.permanentlyLockedOut:
        message = 'Biometric authentication is locked. Please use your password to sign in';
        break;
      case BiometricErrorType.cancelled:
        // User cancelled, don't show error
        return;
      default:
        break;
    }
    
    _showSnackBar(message, isError: true);
    widget.onError?.call();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
          ? HiPopColors.errorPlum 
          : HiPopColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  IconData _getBiometricIcon() {
    if (_availability?.authType == BiometricAuthType.faceId) {
      return Icons.face;
    } else if (_availability?.authType == BiometricAuthType.touchId ||
               _availability?.authType == BiometricAuthType.fingerprint) {
      return Icons.fingerprint;
    }
    return Icons.security;
  }

  String _getButtonLabel() {
    if (!_hasStoredCredentials) {
      return 'Set up ${_availability?.displayName ?? 'Biometric Login'}';
    }
    
    if (_availability?.authType == BiometricAuthType.faceId) {
      return 'Sign in with Face ID';
    } else if (_availability?.authType == BiometricAuthType.touchId) {
      return 'Sign in with Touch ID';
    } else if (_availability?.authType == BiometricAuthType.fingerprint) {
      return 'Sign in with Fingerprint';
    }
    return 'Sign in with Biometrics';
  }

  Color _getUserTypeColor() {
    switch (widget.userType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      case 'shopper':
        return HiPopColors.accentMauve;
      default:
        return HiPopColors.primaryDeepSage;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show button if biometrics not available
    if (_availability == null || !_availability!.isAvailable) {
      return const SizedBox.shrink();
    }

    final bool isDarkTheme = widget.userType == 'shopper' || 
                            widget.userType == 'market_organizer';

    if (widget.showQuickAccess && _hasStoredCredentials) {
      // Quick access mode - larger, more prominent button
      return _buildQuickAccessButton(isDarkTheme);
    }

    // Standard mode - compact button below password field
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: _buildStandardButton(isDarkTheme),
          ),
        );
      },
    );
  }

  Widget _buildQuickAccessButton(bool isDarkTheme) {
    final Color accentColor = _getUserTypeColor();
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isAuthenticating ? null : _handleBiometricAuth,
          borderRadius: BorderRadius.circular(16),
          splashColor: accentColor.withOpacity( 0.1),
          highlightColor: accentColor.withOpacity( 0.05),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withOpacity( 0.05),
                  accentColor.withOpacity( 0.1),
                ],
              ),
              border: Border.all(
                color: accentColor.withOpacity( 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _getBiometricIcon(),
                    size: _isAuthenticating ? 48 : 56,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isAuthenticating ? 'Authenticating...' : _getButtonLabel(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkTheme 
                      ? HiPopColors.darkTextPrimary 
                      : accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quick and secure access',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkTheme 
                      ? HiPopColors.darkTextSecondary 
                      : Colors.grey[600],
                  ),
                ),
                if (_isAuthenticating) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
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

  Widget _buildStandardButton(bool isDarkTheme) {
    final Color accentColor = _getUserTypeColor();
    
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(top: 8),
      child: OutlinedButton.icon(
        onPressed: _isAuthenticating ? null : _handleBiometricAuth,
        icon: _isAuthenticating
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : Icon(
              _getBiometricIcon(),
              color: accentColor,
            ),
        label: Text(
          _isAuthenticating ? 'Authenticating...' : _getButtonLabel(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: accentColor,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: accentColor.withOpacity( 0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: isDarkTheme 
            ? HiPopColors.darkSurfaceVariant.withOpacity( 0.5)
            : accentColor.withOpacity( 0.05),
        ),
      ),
    );
  }
}