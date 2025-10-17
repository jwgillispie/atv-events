import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_event.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../../shared/services/user/user_profile_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class MarketOrganizerComprehensiveSignupScreen extends StatefulWidget {
  const MarketOrganizerComprehensiveSignupScreen({super.key});

  @override
  State<MarketOrganizerComprehensiveSignupScreen> createState() => _MarketOrganizerComprehensiveSignupScreenState();
}

class _MarketOrganizerComprehensiveSignupScreenState extends State<MarketOrganizerComprehensiveSignupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;
  bool _isLoading = false;

  // Step 1: Basic Auth
  final _step1FormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2: Organization Info
  final _step2FormKey = GlobalKey<FormState>();
  final _organizationNameController = TextEditingController();
  final _bioController = TextEditingController();

  // Step 3: Contact Details
  final _step3FormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _organizationNameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          // Don't navigate to dashboard immediately - complete profile first
          _completeProfileSetup(state.user.uid);
        } else if (state is AuthError) {
          setState(() => _isLoading = false);
          _showErrorSnackBar(state.message);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Market Organizer Setup'),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: HiPopColors.primaryGradient,
            ),
          ),
          foregroundColor: Colors.white,
        ),
        backgroundColor: HiPopColors.darkBackground,
        body: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                border: Border(bottom: BorderSide(color: HiPopColors.darkBorder)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step ${_currentStep + 1} of $_totalSteps',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      Text(
                        '${((_currentStep + 1) / _totalSteps * 100).round()}% Complete',
                        style: TextStyle(color: HiPopColors.darkTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _totalSteps,
                    backgroundColor: HiPopColors.organizerAccent.withOpacity( 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.organizerAccent),
                  ),
                ],
              ),
            ),
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1BasicAuth(),
                  _buildStep2OrganizationInfo(),
                  _buildStep3ContactDetails(),
                  _buildStep4Review(),
                ],
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                border: Border(top: BorderSide(color: HiPopColors.darkBorder)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: HiPopColors.organizerAccent,
                          side: BorderSide(color: HiPopColors.organizerAccent.withOpacity( 0.5)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: HiPopColors.organizerAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(_currentStep == _totalSteps - 1 ? 'Submit Profile' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1BasicAuth() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: HiPopColors.darkBackground,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
        child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
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
              'Let\'s start with your basic account information.',
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
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStep2OrganizationInfo() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Organization Information',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your organization and markets.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _organizationNameController,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Organization Name *',
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your organization name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              maxLines: 5,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Organization Description *',
                labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                hintText: 'Describe your organization, the markets you manage, your mission, and experience...',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.darkBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
                ),
                alignLabelWithHint: true,
                fillColor: HiPopColors.darkSurface,
                filled: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an organization description';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Container(
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
                        'What to Include',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• How long you\'ve been organizing markets\n'
                    '• Types of markets you run (farmers, artisan, etc.)\n'
                    '• Your community involvement\n'
                    '• What makes your markets special',
                    style: TextStyle(color: HiPopColors.darkTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStep3ContactDetails() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Text(
              'Contact Information',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: HiPopColors.darkTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'How can vendors and the community reach you?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Phone Number *',
                labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                hintText: '(555) 123-4567',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.phone, color: HiPopColors.organizerAccent),
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
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              keyboardType: TextInputType.url,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Website',
                labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                hintText: 'https://your-market-website.com',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.language, color: HiPopColors.organizerAccent),
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
            TextFormField(
              controller: _instagramController,
              style: TextStyle(color: HiPopColors.darkTextPrimary),
              decoration: InputDecoration(
                labelText: 'Instagram Handle',
                labelStyle: TextStyle(color: HiPopColors.organizerAccent),
                hintText: '@your_market_name',
                hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
                prefixIcon: Icon(Icons.camera_alt, color: HiPopColors.organizerAccent),
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
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStep4Review() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(
            'Review & Submit',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please review your information before submitting.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: HiPopColors.darkTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Review cards
          _buildReviewCard(
            'Basic Information',
            [
              'Name: ${_nameController.text}',
              'Email: ${_emailController.text}',
            ],
            Icons.person,
          ),
          const SizedBox(height: 16),
          
          _buildReviewCard(
            'Organization',
            [
              'Name: ${_organizationNameController.text}',
              'Description: ${_bioController.text.length > 50 ? '${_bioController.text.substring(0, 50)}...' : _bioController.text}',
            ],
            Icons.business,
          ),
          const SizedBox(height: 16),
          
          _buildReviewCard(
            'Contact Details',
            [
              'Phone: ${_phoneController.text.isEmpty ? 'Not provided' : _phoneController.text}',
              'Website: ${_websiteController.text.isEmpty ? 'Not provided' : _websiteController.text}',
              'Instagram: ${_instagramController.text.isEmpty ? 'Not provided' : _instagramController.text}',
            ],
            Icons.contact_phone,
          ),
          
          const SizedBox(height: 32),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HiPopColors.darkBorder),
            ),
            child: Column(
              children: [
                Icon(Icons.pending_actions, color: HiPopColors.organizerAccent, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Ready to Submit!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: HiPopColors.darkTextPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'After you submit your profile, we\'ll review your account and get back to you soon. You\'ll receive an email when your account is approved!',
                  style: TextStyle(color: HiPopColors.darkTextSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildReviewCard(String title, List<String> items, IconData icon) {
    return Card(
      color: HiPopColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: HiPopColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: HiPopColors.organizerAccent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: HiPopColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    item,
                    style: TextStyle(color: HiPopColors.darkTextSecondary),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    bool canProceed = false;

    switch (_currentStep) {
      case 0:
        canProceed = _step1FormKey.currentState?.validate() ?? false;
        break;
      case 1:
        canProceed = _step2FormKey.currentState?.validate() ?? false;
        break;
      case 2:
        canProceed = _step3FormKey.currentState?.validate() ?? false;
        break;
      case 3:
        // Final step - create account and submit profile
        _createAccountAndSubmitProfile();
        return;
    }

    if (canProceed && _currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createAccountAndSubmitProfile() async {
    setState(() => _isLoading = true);

    try {
      context.read<AuthBloc>().add(SignUpEvent(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        userType: 'market_organizer',
      ));
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error creating account: $e');
    }
  }

  Future<void> _completeProfileSetup(String userId) async {
    try {
      final userProfileService = UserProfileService();
      
      // Create comprehensive profile
      final newProfile = await userProfileService.createUserProfile(
        userId: userId,
        userType: 'market_organizer',
        email: _emailController.text.trim(),
        displayName: _nameController.text.trim(),
      );

      // Update with all the collected information
      final updatedProfile = newProfile.copyWith(
        organizationName: _organizationNameController.text.trim(),
        bio: _bioController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        instagramHandle: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
        profileSubmitted: true,
        verificationRequestedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userProfileService.updateUserProfile(updatedProfile);
      
      setState(() => _isLoading = false);
      
      // Move to next step to show profile complete
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error setting up profile: $e');
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