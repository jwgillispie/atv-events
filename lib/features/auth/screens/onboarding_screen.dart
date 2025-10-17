import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/onboarding_service.dart';
import 'package:atv_events/core/theme/atv_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = true;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.storefront,
      title: 'Discover Pop-ups',
      subtitle: 'Find amazing local vendors and unique pop-up events near you',
      description: 'Browse food trucks, local artists, and small businesses in your area. Search by location and distance.',
    ),
    OnboardingPage(
      icon: Icons.location_on,
      title: 'Location-Based Search',
      subtitle: 'Search by location and set your preferred radius',
      description: 'Use our smart location search to find pop-ups within your desired distance. Real-time updates keep you informed.',
    ),
    OnboardingPage(
      icon: Icons.favorite,
      title: 'Save Your Favorites',
      subtitle: 'Bookmark vendors and events you love',
      description: 'Free: Follow 10 vendors. Upgrade to Premium for unlimited follows and advanced search filters.',
    ),
    OnboardingPage(
      icon: Icons.schedule,
      title: 'Never Miss Out',
      subtitle: 'Get notifications about your favorite vendors',
      description: 'Stay updated with pop-up events and market schedules. Premium users get priority notifications.',
    ),
    OnboardingPage(
      icon: Icons.workspace_premium,
      title: 'Unlock Premium',
      subtitle: 'Enhanced discovery for just \$4/month',
      description: 'Unlimited vendor follows, advanced filters, personalized recommendations, and vendor appearance predictions.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    // Check if shopper should see onboarding (first time signup and not completed)
    final shouldShow = await OnboardingService.shouldShowShopperOnboarding();
    
    if (mounted) {
      if (!shouldShow) {
        // Don't show onboarding, redirect to auth
        context.go('/auth');
      } else {
        // Show onboarding
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    // Mark onboarding as completed and clear first time flag
    await OnboardingService.markShopperOnboardingComplete();
    await OnboardingService.clearFirstTimeSignupFlag();
    if (mounted) {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking onboarding status
    if (_isLoading) {
      return Scaffold(
        backgroundColor: HiPopColors.darkBackground,
        body: Center(
          child: CircularProgressIndicator(
            color: HiPopColors.shopperAccent,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  style: TextButton.styleFrom(
                    foregroundColor: HiPopColors.shopperAccent,
                  ),
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: HiPopColors.darkTextSecondary,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  // Special handling for premium page
                  if (index == _pages.length - 1) {
                    return _buildPremiumPageContent(_pages[index]);
                  }
                  return _buildPageContent(_pages[index]);
                },
              ),
            ),
            // Page indicators
            _buildPageIndicators(),
            const SizedBox(height: 24),
            // Navigation buttons
            _buildNavigationButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity( 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.orange[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: HiPopColors.darkTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumPageContent(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Premium icon with gradient
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: HiPopColors.premiumGradient,
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 48),
          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: HiPopColors.darkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.purple[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Description
          Text(
            page.description,
            style: TextStyle(
              fontSize: 16,
              color: HiPopColors.darkTextSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Premium features list
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: HiPopColors.premiumGold.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HiPopColors.premiumGold.withOpacity( 0.3)),
            ),
            child: Column(
              children: [
                _buildPremiumFeature(Icons.people, 'Unlimited vendor follows'),
                _buildPremiumFeature(Icons.search, 'Advanced search filters'),
                _buildPremiumFeature(Icons.recommend, 'Personalized recommendations'),
                _buildPremiumFeature(Icons.schedule, 'Vendor appearance predictions'),
                _buildPremiumFeature(Icons.priority_high, 'Priority notifications'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumFeature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.purple.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.purple.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? HiPopColors.shopperAccent : HiPopColors.darkTextTertiary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        children: [
          // Previous button
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
                style: OutlinedButton.styleFrom(
                  foregroundColor: HiPopColors.shopperAccent,
                  side: BorderSide(color: HiPopColors.shopperAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Previous'),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          
          const SizedBox(width: 16),
          
          // Next/Get Started button
          Expanded(
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: HiPopColors.shopperAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
  });
}