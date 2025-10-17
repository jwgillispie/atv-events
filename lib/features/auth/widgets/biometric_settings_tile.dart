import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/hipop_colors.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/auth/auth_event.dart';
import '../../../blocs/auth/auth_state.dart';
import '../services/biometric_auth_service.dart';

/// Settings tile for managing biometric authentication
/// Allows users to enable/disable Face ID, Touch ID, or fingerprint authentication
class BiometricSettingsTile extends StatefulWidget {
  final String userType;
  final VoidCallback? onSettingsChanged;
  
  const BiometricSettingsTile({
    super.key,
    required this.userType,
    this.onSettingsChanged,
  });

  @override
  State<BiometricSettingsTile> createState() => _BiometricSettingsTileState();
}

class _BiometricSettingsTileState extends State<BiometricSettingsTile> {
  final BiometricAuthService _biometricService = BiometricAuthService();
  
  bool _isLoading = false;
  bool _biometricEnabled = false;
  bool _hasStoredCredentials = false;
  BiometricAvailability? _availability;
  
  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
  }
  
  Future<void> _loadBiometricSettings() async {
    final availability = await _biometricService.checkBiometricAvailability();
    final enabled = await _biometricService.isBiometricEnabled();
    final hasCredentials = await _biometricService.hasStoredCredentials();
    
    if (mounted) {
      setState(() {
        _availability = availability;
        _biometricEnabled = enabled;
        _hasStoredCredentials = hasCredentials;
      });
    }
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
  
  IconData _getBiometricIcon() {
    if (_availability?.authType == BiometricAuthType.faceId) {
      return Icons.face;
    } else if (_availability?.authType == BiometricAuthType.touchId ||
               _availability?.authType == BiometricAuthType.fingerprint) {
      return Icons.fingerprint;
    }
    return Icons.security;
  }
  
  String _getBiometricTitle() {
    if (_availability == null || !_availability!.isAvailable) {
      return 'Biometric Login';
    }
    return _availability!.displayName ?? 'Biometric Login';
  }
  
  String _getBiometricSubtitle() {
    if (_availability == null) {
      return 'Checking availability...';
    }
    
    if (!_availability!.isAvailable) {
      return _availability!.reason ?? 'Not available on this device';
    }
    
    if (!_hasStoredCredentials && _biometricEnabled) {
      return 'Login with password to save credentials';
    }
    
    return _biometricEnabled 
      ? 'Quick and secure access enabled' 
      : 'Enable for faster sign-in';
  }
  
  Future<void> _toggleBiometric(bool value) async {
    if (_isLoading) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() => _isLoading = true);
    
    try {
      if (value) {
        // Enabling biometric
        if (!_hasStoredCredentials) {
          // Need to authenticate first to save credentials
          await _showCredentialDialog();
        } else {
          // Just enable biometric
          await _biometricService.setBiometricEnabled(true);
          _showSuccessSnackBar('${_getBiometricTitle()} enabled');
        }
      } else {
        // Disabling biometric - confirm first
        final shouldDisable = await _showDisableConfirmDialog();
        if (shouldDisable == true) {
          await _biometricService.setBiometricEnabled(false);
          await _biometricService.clearCredentials();
          _showSuccessSnackBar('${_getBiometricTitle()} disabled');
        }
      }
      
      await _loadBiometricSettings();
      widget.onSettingsChanged?.call();
      
    } catch (e) {
      _showErrorSnackBar('Failed to update biometric settings');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _showCredentialDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        final bool isDarkTheme = widget.userType == 'shopper' || 
                                widget.userType == 'market_organizer';
        final Color accentColor = _getUserTypeColor();
        
        return AlertDialog(
          backgroundColor: isDarkTheme ? HiPopColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isDarkTheme 
              ? BorderSide(
                  color: HiPopColors.accentMauve.withOpacity( 0.3),
                  width: 1,
                )
              : BorderSide.none,
          ),
          title: Text(
            'Enable ${_getBiometricTitle()}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sign in once to save your credentials securely for ${_getBiometricTitle()}.',
                  style: TextStyle(
                    color: isDarkTheme 
                      ? HiPopColors.darkTextSecondary 
                      : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(
                    color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: accentColor),
                    filled: true,
                    fillColor: isDarkTheme 
                      ? HiPopColors.darkSurfaceVariant 
                      : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  style: TextStyle(
                    color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: accentColor),
                    filled: true,
                    fillColor: isDarkTheme 
                      ? HiPopColors.darkSurfaceVariant 
                      : Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accentColor, width: 2),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkTheme 
                    ? HiPopColors.darkTextSecondary 
                    : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Authenticate and save credentials
                  try {
                    // Get auth bloc before async gap
                    final authBloc = dialogContext.mounted ? dialogContext.read<AuthBloc>() : null;
                    if (authBloc == null) {
                      Navigator.of(dialogContext).pop(false);
                      return;
                    }
                    
                    // First authenticate with Firebase
                    authBloc.add(LoginEvent(
                      email: emailController.text.trim(),
                      password: passwordController.text.trim(),
                    ));
                    
                    // Wait for authentication to complete
                    await Future.delayed(const Duration(seconds: 2));
                    
                    if (!dialogContext.mounted) return;
                    
                    if (authBloc.state is Authenticated) {
                      final authState = authBloc.state as Authenticated;
                      
                      // Save credentials for biometric
                      await _biometricService.saveCredentials(
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                        userType: widget.userType,
                        userId: authState.user.uid,
                      );
                      
                      await _biometricService.setBiometricEnabled(true);
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } else {
                      // Authentication failed
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(false);
                      }
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop(false);
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );
    
    if (result == true) {
      _showSuccessSnackBar('${_getBiometricTitle()} enabled successfully');
    }
  }
  
  Future<bool?> _showDisableConfirmDialog() async {
    final bool isDarkTheme = widget.userType == 'shopper' || 
                            widget.userType == 'market_organizer';
    
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDarkTheme ? HiPopColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isDarkTheme 
              ? BorderSide(
                  color: HiPopColors.accentMauve.withOpacity( 0.3),
                  width: 1,
                )
              : BorderSide.none,
          ),
          title: Text(
            'Disable ${_getBiometricTitle()}?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
            ),
          ),
          content: Text(
            'You will need to enter your email and password to sign in.',
            style: TextStyle(
              color: isDarkTheme 
                ? HiPopColors.darkTextSecondary 
                : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDarkTheme 
                    ? HiPopColors.darkTextSecondary 
                    : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.errorPlum,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Disable'),
            ),
          ],
        );
      },
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.errorPlum,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = widget.userType == 'shopper' || 
                            widget.userType == 'market_organizer';
    final Color accentColor = _getUserTypeColor();
    
    // Don't show if biometric not available
    if (_availability != null && !_availability!.isAvailable) {
      return const SizedBox.shrink();
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDarkTheme 
          ? HiPopColors.darkSurface 
          : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkTheme 
            ? HiPopColors.darkBorder.withOpacity( 0.5)
            : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: isDarkTheme 
          ? []
          : [
              BoxShadow(
                color: Colors.black.withOpacity( 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor.withOpacity( 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getBiometricIcon(),
            color: accentColor,
            size: 24,
          ),
        ),
        title: Text(
          _getBiometricTitle(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
        ),
        subtitle: Text(
          _getBiometricSubtitle(),
          style: TextStyle(
            fontSize: 14,
            color: isDarkTheme 
              ? HiPopColors.darkTextSecondary 
              : Colors.grey[600],
          ),
        ),
        trailing: _isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            )
          : Switch.adaptive(
              value: _biometricEnabled && _hasStoredCredentials,
              onChanged: (_availability != null && _availability!.isAvailable) 
                ? _toggleBiometric 
                : null,
              activeColor: accentColor,
            ),
      ),
    );
  }
}