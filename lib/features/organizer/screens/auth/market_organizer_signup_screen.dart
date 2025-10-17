import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/blocs/auth/auth_bloc.dart';
import 'package:atv_events/blocs/auth/auth_event.dart';
import 'package:atv_events/blocs/auth/auth_state.dart';
import 'package:atv_events/features/shared/services/user/user_profile_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class MarketOrganizerSignupScreen extends StatefulWidget {
  const MarketOrganizerSignupScreen({super.key});

  @override
  State<MarketOrganizerSignupScreen> createState() => _MarketOrganizerSignupScreenState();
}

class _MarketOrganizerSignupScreenState extends State<MarketOrganizerSignupScreen> {
  // Account Info Form
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _organizationController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // Account created successfully, navigate to dashboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created successfully! Welcome to HiPop!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/organizer');
        } else if (state is AuthError) {
          setState(() => _isLoading = false);
          _showErrorSnackBar(state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Market Organizer Signup'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: HiPopColors.primaryGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        backgroundColor: HiPopColors.darkBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  
                  // Welcome text
                  Text(
                    'Create Your Market Organizer Account',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Join HiPop to manage your farmers markets and connect with vendors.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HiPopColors.darkTextSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  
                  // Already have an account section
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/auth'),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 14),
                          children: [
                            TextSpan(
                              text: 'Already have an account? ',
                              style: TextStyle(color: HiPopColors.darkTextSecondary),
                            ),
                            TextSpan(
                              text: 'Sign In',
                              style: TextStyle(
                                color: HiPopColors.organizerAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                      hintText: 'Enter your full name',
                      hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                      prefixIcon: Icon(Icons.person, color: HiPopColors.organizerAccent),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                      ),
                      fillColor: HiPopColors.darkSurface,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                      hintText: 'Enter your email address',
                      hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                      prefixIcon: Icon(Icons.email, color: HiPopColors.organizerAccent),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                      ),
                      fillColor: HiPopColors.darkSurface,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Organization Name Field
                  TextFormField(
                    controller: _organizationController,
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Organization Name (Optional)',
                      labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                      hintText: 'e.g., Atlanta Farmers Market Association',
                      hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                      prefixIcon: Icon(Icons.business, color: HiPopColors.organizerAccent),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                      ),
                      fillColor: HiPopColors.darkSurface,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                      hintText: 'Enter your password',
                      hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                      prefixIcon: Icon(Icons.lock, color: HiPopColors.organizerAccent),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                      ),
                      fillColor: HiPopColors.darkSurface,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    style: TextStyle(color: HiPopColors.darkTextPrimary),
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                      hintText: 'Confirm your password',
                      hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                      prefixIcon: Icon(Icons.lock_outline, color: HiPopColors.organizerAccent),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.darkBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                      ),
                      fillColor: HiPopColors.darkSurface,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.organizerAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Sign In Link
                  TextButton(
                    onPressed: () => context.go('/signin'),
                    style: TextButton.styleFrom(
                      foregroundColor: HiPopColors.organizerAccent,
                    ),
                    child: const Text('Already have an account? Sign In'),
                  ),

                  const SizedBox(height: 24),

                  // Info card
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: HiPopColors.darkBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info, color: HiPopColors.organizerAccent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'What\'s Next?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'After creating your account, you can:\n'
                          '• Create and manage your markets\n'
                          '• Invite and manage vendors\n'
                          '• Track analytics and performance\n'
                          '• Connect with your community',
                          style: TextStyle(color: HiPopColors.darkTextSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Create the user account
      context.read<AuthBloc>().add(SignUpEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: 'market_organizer',
      ));

      // Wait for authentication to complete
      await _waitForAuthentication();

      // Create user profile with organization name if provided
      final userProfileService = UserProfileService();
      final currentUserId = await userProfileService.getCurrentUserId();
      
      if (currentUserId != null) {
        // Check if profile already exists
        final existingProfile = await userProfileService.getUserProfile(currentUserId);
        if (existingProfile == null) {
          // Create new profile
          final newProfile = await userProfileService.createUserProfile(
            userId: currentUserId,
            userType: 'market_organizer',
            email: _emailController.text.trim(),
            displayName: _nameController.text.trim(),
          );
          
          // Update with organization name if provided
          if (_organizationController.text.trim().isNotEmpty) {
            final updatedProfile = newProfile.copyWith(
              organizationName: _organizationController.text.trim(),
              updatedAt: DateTime.now(),
            );
            await userProfileService.updateUserProfile(updatedProfile);
          }
        } else {
          // Update existing profile with organization name
          final updatedProfile = existingProfile.copyWith(
            organizationName: _organizationController.text.trim().isNotEmpty 
                ? _organizationController.text.trim() 
                : null,
            updatedAt: DateTime.now(),
          );
          await userProfileService.updateUserProfile(updatedProfile);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error creating account: $e');
      }
    }
  }

  Future<void> _waitForAuthentication() async {
    final authBloc = context.read<AuthBloc>();
    
    // Wait for authentication to complete
    await for (final state in authBloc.stream) {
      if (state is Authenticated) {
        break;
      } else if (state is AuthError) {
        throw Exception(state.message);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}