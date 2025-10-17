import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/auth/services/password_reset_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? userType;
  
  const ForgotPasswordScreen({super.key, this.userType});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> 
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Unfocus keyboard
    _emailFocusNode.unfocus();
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Add haptic feedback for better UX
    HapticFeedback.lightImpact();
    
    try {
      await PasswordResetService.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      
      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
      
      // Success haptic feedback
      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _errorMessage = _formatErrorMessage(e.toString());
        _isLoading = false;
      });
      
      // Error haptic feedback
      HapticFeedback.heavyImpact();
    }
  }
  
  String _formatErrorMessage(String error) {
    error = error.replaceAll('Exception: ', '');
    
    // Provide user-friendly error messages
    if (error.contains('user-not-found')) {
      return 'No account found with this email address. Please check and try again.';
    } else if (error.contains('invalid-email')) {
      return 'The email address is invalid. Please enter a valid email.';
    } else if (error.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    } else if (error.contains('network')) {
      return 'Network error. Please check your connection and try again.';
    }
    
    return error;
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
  
  bool get _isDarkTheme => widget.userType == 'shopper' || widget.userType == 'market_organizer';
  
  // Safe navigation helper that uses go() instead of pop()
  void _navigateToLogin() {
    final userType = widget.userType ?? 'shopper';
    // Always use go() for absolute navigation to avoid stack issues
    context.go('/login?type=$userType');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkTheme ? HiPopColors.darkBackground : HiPopColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: _isDarkTheme 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _isDarkTheme ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
            size: 20,
          ),
          onPressed: _navigateToLogin,
          tooltip: 'Back to Login',
        ),
        title: Text(
          'Password Reset',
          style: TextStyle(
            color: _isDarkTheme ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _emailSent ? _buildSuccessContent() : _buildResetForm(),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildResetForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        elevation: _isDarkTheme ? 0 : 4,
        color: _isDarkTheme ? HiPopColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _isDarkTheme
              ? BorderSide(
                  color: HiPopColors.accentMauve.withOpacity( 0.2),
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Enhanced icon with background
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _getUserTypeColor().withOpacity( 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_reset_rounded,
                    size: 48,
                    color: _getUserTypeColor(),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Forgot Your Password?',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: _isDarkTheme ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'No worries! Enter your email address below and we\'ll send you instructions to reset your password.',
                  style: TextStyle(
                    fontSize: 15,
                    color: _isDarkTheme ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  autocorrect: false,
                  enableSuggestions: true,
                  style: TextStyle(
                    color: _isDarkTheme ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
                    fontSize: 16,
                  ),
                  onFieldSubmitted: (_) => _sendPasswordResetEmail(),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'yourname@example.com',
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: _isDarkTheme ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                      size: 22,
                    ),
                    filled: true,
                    fillColor: _isDarkTheme 
                        ? HiPopColors.darkSurfaceVariant 
                        : HiPopColors.lightSurfaceVariant.withOpacity( 0.7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: _isDarkTheme
                          ? BorderSide(color: HiPopColors.darkBorder.withOpacity( 0.3))
                          : BorderSide(color: Colors.grey.withOpacity( 0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _getUserTypeColor(),
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: HiPopColors.errorPlum,
                        width: 1,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: HiPopColors.errorPlum,
                        width: 2,
                      ),
                    ),
                    labelStyle: TextStyle(
                      color: _isDarkTheme ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                      fontSize: 15,
                    ),
                    hintStyle: TextStyle(
                      color: _isDarkTheme 
                          ? HiPopColors.darkTextSecondary.withOpacity( 0.5)
                          : HiPopColors.lightTextSecondary.withOpacity( 0.5),
                      fontSize: 15,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email address';
                    }
                    final email = value.trim().toLowerCase();
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HiPopColors.errorPlum.withOpacity( 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HiPopColors.errorPlum.withOpacity( 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: HiPopColors.errorPlum,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: HiPopColors.errorPlum,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Send Reset Email Button
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendPasswordResetEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getUserTypeColor(),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _getUserTypeColor().withOpacity( 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: _isDarkTheme ? 0 : 2,
                      shadowColor: _getUserTypeColor().withOpacity( 0.3),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.send_rounded, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  'Send Reset Email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Back to Login Button - FIXED NAVIGATION
                TextButton(
                  onPressed: _navigateToLogin,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        color: _getUserTypeColor(),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back to Login',
                        style: TextStyle(
                          color: _getUserTypeColor(),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSuccessContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Card(
        elevation: _isDarkTheme ? 0 : 4,
        color: _isDarkTheme ? HiPopColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: _isDarkTheme
              ? BorderSide(
                  color: HiPopColors.successGreen.withOpacity( 0.2),
                  width: 1,
                )
              : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success icon with animated background
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            HiPopColors.successGreen.withOpacity( 0.15),
                            HiPopColors.successGreen.withOpacity( 0.05),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_read_rounded,
                        size: 52,
                        color: HiPopColors.successGreen,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Email Sent Successfully!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _isDarkTheme ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We\'ve sent password reset instructions to:',
                style: TextStyle(
                  fontSize: 15,
                  color: _isDarkTheme ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _getUserTypeColor().withOpacity( 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _getUserTypeColor().withOpacity( 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  _emailController.text.trim(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _getUserTypeColor(),
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),
              // Information box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _isDarkTheme
                      ? HiPopColors.darkSurfaceVariant
                      : HiPopColors.infoBlueGray.withOpacity( 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: HiPopColors.infoBlueGray.withOpacity( 0.15),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.tips_and_updates_rounded,
                          color: HiPopColors.infoBlueGray,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Next Steps:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _isDarkTheme 
                                      ? HiPopColors.darkTextPrimary 
                                      : HiPopColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '1. Check your email inbox\n'
                                '2. Click the reset link in the email\n'
                                '3. Create a new secure password\n'
                                '4. Sign in with your new password',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isDarkTheme 
                                      ? HiPopColors.darkTextSecondary 
                                      : HiPopColors.lightTextSecondary,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      color: HiPopColors.infoBlueGray.withOpacity( 0.2),
                      height: 20,
                    ),
                    Text(
                      'Didn\'t receive the email? Check your spam folder or try again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isDarkTheme 
                            ? HiPopColors.darkTextSecondary 
                            : HiPopColors.lightTextSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              // Back to Login Button - FIXED NAVIGATION
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _navigateToLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getUserTypeColor(),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: _isDarkTheme ? 0 : 2,
                    shadowColor: _getUserTypeColor().withOpacity( 0.3),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.login_rounded, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Return to Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Try Different Email Button
              TextButton(
                onPressed: () {
                  setState(() {
                    _emailSent = false;
                    _errorMessage = null;
                    // Keep the email for convenience
                  });
                  // Add subtle animation
                  _animationController.reset();
                  _animationController.forward();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Send to a different email',
                  style: TextStyle(
                    color: _getUserTypeColor(),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: _getUserTypeColor().withOpacity( 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}