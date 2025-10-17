import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';

/// Simplified signup screen with only essential fields
/// Following Square's approach: email, password, user type
class SimplifiedSignupScreen extends StatefulWidget {
  final String? initialUserType;
  final String? returnPath;

  const SimplifiedSignupScreen({
    super.key,
    this.initialUserType,
    this.returnPath,
  });

  @override
  State<SimplifiedSignupScreen> createState() => _SimplifiedSignupScreenState();
}

class _SimplifiedSignupScreenState extends State<SimplifiedSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedUserType = 'vendor'; // default to vendor
  bool _termsAccepted = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserType != null) {
      _selectedUserType = widget.initialUserType!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      _showErrorSnackBar('Please accept the Terms of Service to continue');
      return;
    }

    context.read<AuthBloc>().add(SignUpEvent(
      name: _emailController.text.split('@')[0], // Use email prefix as temp name
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      userType: _selectedUserType,
    ));
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

  Color _getAccentColor() {
    switch (_selectedUserType) {
      case 'vendor':
        return HiPopColors.vendorAccent;
      case 'market_organizer':
        return HiPopColors.organizerAccent;
      case 'shopper':
        return HiPopColors.accentMauve;
      default:
        return HiPopColors.accentMauve;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          _showErrorSnackBar(state.message);
        } else if (state is Authenticated) {
          // Navigate to Square connection (optional step)
          if (_selectedUserType == 'vendor' || _selectedUserType == 'market_organizer') {
            context.go('/auth/connect-integrations?type=$_selectedUserType');
          } else {
            // Shoppers skip straight to profile completion
            context.go('/auth/complete-profile');
          }
        }
      },
      child: Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: HiPopColors.darkTextPrimary),
            onPressed: () => context.go('/auth'),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                color: HiPopColors.darkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: HiPopColors.accentMauve.withOpacity(0.3),
                    width: 1,
                  ),
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
                        const SizedBox(height: 24),
                        _buildTermsAcceptance(),
                        const SizedBox(height: 24),
                        _buildSubmitButton(),
                        const SizedBox(height: 16),
                        _buildLoginLink(),
                      ],
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
    return Column(
      children: [
        // Hipop logo
        Image.asset(
          'assets/hipop_logo.png',
          height: 64,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.storefront,
            size: 64,
            color: _getAccentColor(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Join Hipop',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The future of pop-up markets',
          style: TextStyle(
            fontSize: 16,
            color: HiPopColors.darkTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final accentColor = _getAccentColor();

    final InputDecoration baseDecoration = InputDecoration(
      filled: true,
      fillColor: HiPopColors.darkSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: HiPopColors.darkBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: HiPopColors.darkBorder.withOpacity(0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
      hintStyle: TextStyle(
        color: HiPopColors.darkTextSecondary.withOpacity(0.5),
      ),
      prefixIconColor: HiPopColors.darkTextSecondary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User type selector
        Text(
          'I am a...',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: HiPopColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildUserTypeChip('vendor', 'Vendor', Icons.store),
            _buildUserTypeChip('market_organizer', 'Organizer', Icons.business),
            _buildUserTypeChip('shopper', 'Shopper', Icons.shopping_bag),
          ],
        ),
        const SizedBox(height: 24),

        // Email field
        TextFormField(
          controller: _emailController,
          style: const TextStyle(color: HiPopColors.darkTextPrimary),
          decoration: baseDecoration.copyWith(
            labelText: 'Email',
            hintText: 'you@example.com',
            prefixIcon: const Icon(Icons.email_outlined),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Email is required';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Password field
        TextFormField(
          controller: _passwordController,
          style: const TextStyle(color: HiPopColors.darkTextPrimary),
          decoration: baseDecoration.copyWith(
            labelText: 'Password',
            hintText: 'At least 6 characters',
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Password is required';
            }
            if (value.trim().length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildUserTypeChip(String value, String label, IconData icon) {
    final isSelected = _selectedUserType == value;
    Color chipColor;

    switch (value) {
      case 'vendor':
        chipColor = HiPopColors.vendorAccent;
        break;
      case 'market_organizer':
        chipColor = HiPopColors.organizerAccent;
        break;
      default:
        chipColor = HiPopColors.accentMauve;
    }

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? Colors.white : HiPopColors.darkTextSecondary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedUserType = value;
        });
      },
      selectedColor: chipColor,
      backgroundColor: HiPopColors.darkSurfaceVariant,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : HiPopColors.darkTextSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? chipColor : HiPopColors.darkBorder,
        width: isSelected ? 2 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildTermsAcceptance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HiPopColors.darkBorder.withOpacity(0.5)),
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
            activeColor: _getAccentColor(),
            side: const BorderSide(color: HiPopColors.darkTextSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              children: [
                const Text(
                  'I agree to the ',
                  style: TextStyle(
                    fontSize: 13,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/legal'),
                  child: Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontSize: 13,
                      color: _getAccentColor(),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(
                  ' and ',
                  style: TextStyle(
                    fontSize: 13,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/legal'),
                  child: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 13,
                      color: _getAccentColor(),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
              backgroundColor: _getAccentColor(),
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
                : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () => context.go('/login'),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: HiPopColors.darkTextSecondary),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign In',
              style: TextStyle(
                color: _getAccentColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
