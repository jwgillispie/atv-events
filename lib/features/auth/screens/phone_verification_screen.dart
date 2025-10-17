import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/phone_verification_service.dart';
import '../../../core/theme/hipop_colors.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String? returnRoute;

  const PhoneVerificationScreen({
    super.key,
    this.returnRoute,
  });

  @override
  State<PhoneVerificationScreen> createState() => _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final PhoneVerificationService _verificationService = PhoneVerificationService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  bool _isLoading = false;
  bool _codeSent = false;
  String? _verificationId;
  String? _errorMessage;
  int _resendTimer = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendTimer = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _sendVerificationCode() async {
    // Validate phone number
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      return;
    }

    // Basic US phone number validation
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length != 10) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit US phone number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Format phone number with US country code
      final formattedPhone = '+1$cleaned';

      // Send verification code
      _verificationId = await _verificationService.sendVerificationCode(formattedPhone);

      setState(() {
        _codeSent = true;
        _isLoading = false;
      });

      _startResendTimer();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to ${_verificationService.formatPhoneNumber(formattedPhone)}'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter the verification code';
      });
      return;
    }

    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code';
      });
      return;
    }

    if (_verificationId == null) {
      setState(() {
        _errorMessage = 'Please request a new verification code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Verify the code
      final success = await _verificationService.verifyCode(_verificationId!, code);

      if (success && mounted) {
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: HiPopColors.successGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: HiPopColors.successGreen,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Phone Verified!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your phone number has been verified successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: HiPopColors.warningAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        color: HiPopColors.warningAmber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Account Tier 2',
                        style: TextStyle(
                          color: HiPopColors.warningAmber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Navigate to appropriate screen
                  if (widget.returnRoute != null) {
                    context.go(widget.returnRoute!);
                  } else {
                    // Determine where to go based on user type
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      // Get user type and navigate accordingly
                      context.go('/');
                    }
                  }
                },
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendTimer > 0) return;

    setState(() {
      _codeSent = false;
      _codeController.clear();
    });

    await _sendVerificationCode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Phone Verification'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header illustration
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: HiPopColors.primaryDeepSage.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_android,
                  size: 60,
                  color: HiPopColors.primaryDeepSage,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                _codeSent ? 'Enter Verification Code' : 'Verify Your Phone',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                _codeSent
                    ? 'We sent a 6-digit code to your phone number'
                    : 'We\'ll send you a verification code to confirm your phone number',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Phone number input or verification code input
              if (!_codeSent) ...[
                // Phone number input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Country code selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[100],
                          ),
                          child: Row(
                            children: [
                              Text(
                                '🇺🇸',
                                style: TextStyle(fontSize: 24),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '+1',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Phone number field
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                              _PhoneNumberFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: '(555) 123-4567',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ] else ...[
                // Verification code input
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Verification Code',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Resend code button
                    Center(
                      child: TextButton(
                        onPressed: _resendTimer == 0 ? _resendCode : null,
                        child: Text(
                          _resendTimer > 0
                              ? 'Resend code in $_resendTimer seconds'
                              : 'Didn\'t receive the code? Resend',
                          style: TextStyle(
                            color: _resendTimer > 0 ? Colors.grey : HiPopColors.primaryDeepSage,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Action button
              ElevatedButton(
                onPressed: _isLoading ? null : (_codeSent ? _verifyCode : _sendVerificationCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor: HiPopColors.primaryDeepSage,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _codeSent ? 'Verify Code' : 'Send Code',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Benefits section
              if (!_codeSent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.primaryDeepSage.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: HiPopColors.primaryDeepSage.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.verified,
                            color: HiPopColors.warningAmber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Benefits of Phone Verification',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem(Icons.flash_on, 'Instant account approval'),
                      _buildBenefitItem(Icons.arrow_upward, 'Upgrade to Tier 2 account'),
                      _buildBenefitItem(Icons.lock_open, 'Access to more features'),
                      _buildBenefitItem(Icons.shield, 'Enhanced account security'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: HiPopColors.primaryDeepSage,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom formatter for US phone numbers
class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final newText = newValue.text;
    final buffer = StringBuffer();
    int selectionIndex = newValue.selection.end;
    int usedSubstringIndex = 0;

    if (newText.length >= 1) {
      buffer.write('(');
      if (newValue.selection.end >= 1) selectionIndex++;
    }

    if (newText.length >= 4) {
      buffer.write(newText.substring(0, usedSubstringIndex = 3) + ') ');
      if (newValue.selection.end >= 3) selectionIndex += 2;
    }

    if (newText.length >= 7) {
      buffer.write(newText.substring(3, usedSubstringIndex = 6) + '-');
      if (newValue.selection.end >= 6) selectionIndex++;
    }

    if (newText.length >= 11) {
      buffer.write(newText.substring(6, usedSubstringIndex = 10));
      if (newValue.selection.end >= 10) selectionIndex++;
    }

    // Handle remaining
    if (newText.length > usedSubstringIndex) {
      buffer.write(newText.substring(usedSubstringIndex));
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}