import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_event.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import '../services/biometric_auth_service.dart';
import '../widgets/biometric_login_button.dart';


class AuthScreen extends StatefulWidget {
  final String userType;
  final bool isLogin;
  final String? returnPath;

  const AuthScreen({
    super.key,
    required this.userType,
    required this.isLogin,
    this.returnPath,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _termsAccepted = false;
  bool _showBiometricSetup = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  bool get _isLogin => widget.isLogin;

  @override
  void initState() {
    super.initState();
    _checkBiometricCredentials();
    // Add listener to email field to check for Face ID when email changes
    if (_isLogin) {
      _emailController.addListener(_onEmailChanged);
    }
  }
  
  Future<void> _checkBiometricCredentials() async {
    if (_isLogin) {
      // Check for legacy credentials first (for migration)
      final hasLegacyCredentials = await _biometricService.hasStoredCredentials();
      if (hasLegacyCredentials && mounted) {
        setState(() {
          _showBiometricSetup = true;
          _rememberMe = true; // Auto-check if credentials are saved
        });
      }
    }
  }
  
  void _onEmailChanged() {
    if (_emailController.text.isEmpty) {
      if (_showBiometricSetup) {
        setState(() {
          _showBiometricSetup = false;
        });
      }
      return;
    }
    
    // Check if this email has Face ID enabled
    _checkBiometricForEmail(_emailController.text.trim());
  }
  
  Future<void> _checkBiometricForEmail(String email) async {
    if (!_isLogin || email.isEmpty || !email.contains('@')) {
      return;
    }

    final hasCredentials = await _biometricService.hasCredentialsForEmail(email);
    if (mounted) {
      setState(() {
        _showBiometricSetup = hasCredentials;
        _rememberMe = hasCredentials; // Auto-check if this email has saved credentials
      });
    }
  }

  @override
  void dispose() {
    if (_isLogin) {
      _emailController.removeListener(_onEmailChanged);
    }
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_isLogin) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorSnackBar('Passwords do not match');
        return;
      }
      
      if (!_termsAccepted) {
        _showErrorSnackBar('Please accept the Terms of Service and Privacy Policy to continue');
        return;
      }
      
      context.read<AuthBloc>().add(SignUpEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: widget.userType,
      ));
    } else {
      context.read<AuthBloc>().add(LoginEvent(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      ));

      // If Remember Me is checked, save credentials for auto-fill
      if (_rememberMe) {
        // Save credentials after successful login (handled in listener)
        // We'll prompt for biometric setup in the listener
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.errorPlum,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _promptBiometricSetup() async {
    // Check if biometric is available
    final availability = await _biometricService.checkBiometricAvailability();
    if (!availability.isAvailable || !mounted) return;
    
    // Check if already enabled
    final isEnabled = await _biometricService.isBiometricEnabled();
    if (isEnabled) return;
    
    if (!mounted) return;
    
    // Show setup dialog
    final bool? shouldEnable = await showDialog<bool>(
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
          title: Row(
            children: [
              Icon(
                availability.authType == BiometricAuthType.faceId 
                  ? Icons.face 
                  : Icons.fingerprint,
                color: accentColor,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enable ${availability.displayName}?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Sign in quickly and securely with ${availability.displayName} next time. Your credentials will be stored securely on this device.',
            style: TextStyle(
              fontSize: 16,
              color: isDarkTheme 
                ? HiPopColors.darkTextSecondary 
                : Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Not Now',
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
    
    if (shouldEnable == true) {
      // Get user ID before async call
      String? userId;
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated) {
          userId = authState.user.uid;
        }
      }
      
      // Enable biometric and save credentials
      await _biometricService.setBiometricEnabled(true);
      await _biometricService.saveCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: widget.userType,
        userId: userId,
      );
      
      if (mounted) {
        setState(() {
          _showBiometricSetup = true;
        });
        
        _showSuccessSnackBar('${availability.displayName} enabled successfully!');
      }
    }
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HiPopColors.successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return Scaffold(
      backgroundColor: isDarkTheme ? HiPopColors.darkBackground : null,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back, 
            color: isDarkTheme ? HiPopColors.darkTextPrimary : Colors.white,
          ),
          onPressed: () => context.go('/auth'),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            _showErrorSnackBar(state.message);
          } else if (state is Authenticated && _isLogin) {
            // After successful login, handle Remember Me
            if (_rememberMe) {
              // Automatically prompt to enable biometric when Remember Me is checked
              _promptBiometricSetup();
            } else {
              // Check if they already have biometric enabled
              _checkBiometricCredentials();
            }
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isDarkTheme 
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: _getGradientColors(),
                ),
            color: isDarkTheme ? HiPopColors.darkBackground : null,
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Card(
                  elevation: isDarkTheme ? 0 : 8,
                  color: isDarkTheme ? HiPopColors.darkSurface : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isDarkTheme 
                      ? BorderSide(
                          color: HiPopColors.accentMauve.withOpacity( 0.3),
                          width: 1,
                        )
                      : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 32),
                          _buildForm(),
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            _buildTermsAcceptance(),
                          ],
                          const SizedBox(height: 24),
                          _buildSubmitButton(),
                          if (_isLogin && _showBiometricSetup) ...[  
                            const SizedBox(height: 12),
                            BiometricLoginButton(
                              userType: widget.userType,
                              email: _emailController.text.trim(),
                              onSuccess: () {
                                // Biometric login successful
                              },
                              onError: () {
                                // Biometric login failed, user can still use password
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildToggleButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return Column(
      children: [
        Icon(
          widget.userType == 'vendor' 
              ? Icons.store 
              : widget.userType == 'market_organizer'
                  ? Icons.business
                  : Icons.shopping_bag,
          size: 64,
          color: _getUserTypeColor(),
        ),
        const SizedBox(height: 16),
        Text(
          '${widget.userType == 'vendor' ? 'Vendor' : widget.userType == 'market_organizer' ? 'Market Organizer' : 'Shopper'} ${_isLogin ? 'Login' : 'Sign Up'}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin 
              ? 'Welcome back! Please sign in'
              : 'Create your account to get started',
          style: TextStyle(
            fontSize: 16,
            color: isDarkTheme 
              ? HiPopColors.darkTextSecondary 
              : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    final Color accentColor = _getUserTypeColor();
    
    final InputDecoration baseDecoration = InputDecoration(
      filled: true,
      fillColor: isDarkTheme ? HiPopColors.darkSurfaceVariant : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDarkTheme 
          ? BorderSide(color: HiPopColors.darkBorder)
          : const BorderSide(),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: isDarkTheme 
          ? BorderSide(color: HiPopColors.darkBorder.withOpacity( 0.5))
          : const BorderSide(),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: accentColor,
          width: 2,
        ),
      ),
      labelStyle: TextStyle(
        color: isDarkTheme ? HiPopColors.darkTextSecondary : null,
      ),
      hintStyle: TextStyle(
        color: isDarkTheme 
          ? HiPopColors.darkTextSecondary.withOpacity( 0.5)
          : null,
      ),
      prefixIconColor: isDarkTheme ? HiPopColors.darkTextSecondary : null,
    );
    
    return Column(
      children: [
        if (!_isLogin) ...[
          TextFormField(
            controller: _nameController,
            style: TextStyle(
              color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
            ),
            decoration: baseDecoration.copyWith(
              labelText: 'Full Name',
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your full name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _emailController,
          style: TextStyle(
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
          decoration: baseDecoration.copyWith(
            labelText: 'Email',
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          style: TextStyle(
            color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
          ),
          decoration: baseDecoration.copyWith(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: isDarkTheme ? HiPopColors.darkTextSecondary : Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            ),
          ),
          obscureText: _obscurePassword,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your password';
            }
            if (!_isLogin && value.trim().length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        if (_isLogin) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() {
                    _rememberMe = value ?? false;
                  });
                },
                activeColor: _getUserTypeColor(),
                side: BorderSide(
                  color: isDarkTheme
                    ? HiPopColors.darkTextSecondary
                    : Colors.grey,
                ),
              ),
              Expanded(
                child: Text(
                  'Remember me on this device',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkTheme
                      ? HiPopColors.darkTextSecondary
                      : Colors.grey[700],
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/forgot-password?type=${widget.userType}');
                },
                child: Text(
                  'Forgot?',
                  style: TextStyle(
                    color: _getUserTypeColor(),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (!_isLogin) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            style: TextStyle(
              color: isDarkTheme ? HiPopColors.darkTextPrimary : null,
            ),
            decoration: baseDecoration.copyWith(
              labelText: 'Confirm Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: isDarkTheme ? HiPopColors.darkTextSecondary : Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                tooltip: _obscureConfirmPassword ? 'Show password' : 'Hide password',
              ),
            ),
            obscureText: _obscureConfirmPassword,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getUserTypeColor(),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _isLogin ? 'Sign In' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildToggleButton() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return TextButton(
      onPressed: () {
        if (_isLogin) {
          context.go('/signup?type=${widget.userType}');
        } else {
          context.go('/login?type=${widget.userType}');
        }
      },
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: isDarkTheme 
              ? HiPopColors.darkTextSecondary
              : Colors.grey[600],
          ),
          children: [
            TextSpan(
              text: _isLogin 
                  ? "Don't have an account? "
                  : 'Already have an account? ',
            ),
            TextSpan(
              text: _isLogin ? 'Sign Up' : 'Sign In',
              style: TextStyle(
                color: _getUserTypeColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getUserTypeColor() {
    switch (widget.userType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      case 'shopper':
        // Use mauve for shopper instead of soft sage
        return HiPopColors.accentMauve;
      default:
        return HiPopColors.accentMauve;
    }
  }

  List<Color> _getGradientColors() {
    switch (widget.userType) {
      case 'vendor':
        return [HiPopColors.vendorAccent, HiPopColors.vendorAccentDark];
      case 'market_organizer':
        return [HiPopColors.organizerAccent, HiPopColors.organizerAccentDark];
      case 'shopper':
        // Use mauve gradient for shoppers
        return [HiPopColors.accentMauve, HiPopColors.accentMauveDark];
      default:
        return [HiPopColors.accentMauve, HiPopColors.accentMauveDark];
    }
  }

  Widget _buildTermsAcceptance() {
    final bool isDarkTheme = widget.userType == 'shopper' || widget.userType == 'market_organizer';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkTheme 
          ? HiPopColors.darkSurfaceVariant 
          : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkTheme 
            ? HiPopColors.darkBorder.withOpacity( 0.5)
            : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _termsAccepted,
            onChanged: (value) {
              setState(() {
                _termsAccepted = value ?? false;
              });
            },
            activeColor: _getUserTypeColor(),
            side: isDarkTheme 
              ? BorderSide(color: HiPopColors.darkTextSecondary)
              : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  children: [
                    Text(
                      'I agree to the ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme 
                          ? HiPopColors.darkTextPrimary
                          : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/legal'),
                      child: Text(
                        'Terms of Service',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getUserTypeColor(),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    Text(
                      ' and ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkTheme 
                          ? HiPopColors.darkTextPrimary
                          : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/legal'),
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getUserTypeColor(),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'This includes consent for payment processing through Stripe, analytics data collection, and our three-sided marketplace platform terms.',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDarkTheme 
                      ? HiPopColors.darkTextSecondary
                      : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}