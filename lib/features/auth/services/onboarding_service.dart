import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _organizerOnboardingKey = 'organizer_onboarding_completed';
  static const String _shopperOnboardingKey = 'shopper_onboarding_completed';
  static const String _vendorOnboardingKey = 'vendor_onboarding_completed';
  static const String _shopperFirstTimeSignupKey = 'shopper_first_time_signup';

  /// Check if market organizer onboarding has been completed
  static Future<bool> isOrganizerOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_organizerOnboardingKey) ?? false;
  }

  /// Mark market organizer onboarding as completed
  static Future<void> markOrganizerOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_organizerOnboardingKey, true);
  }

  /// Reset market organizer onboarding (for testing or re-showing)
  static Future<void> resetOrganizerOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_organizerOnboardingKey);
  }

  /// Check if shopper onboarding has been completed
  static Future<bool> isShopperOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_shopperOnboardingKey) ?? false;
  }

  /// Mark shopper onboarding as completed
  static Future<void> markShopperOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shopperOnboardingKey, true);
  }

  /// Reset shopper onboarding (for testing or re-showing)
  static Future<void> resetShopperOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopperOnboardingKey);
  }

  /// Mark that a shopper has just signed up for the first time
  static Future<void> markShopperFirstTimeSignup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shopperFirstTimeSignupKey, true);
  }

  /// Check if shopper should see onboarding (first time signup and onboarding not completed)
  static Future<bool> shouldShowShopperOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTime = prefs.getBool(_shopperFirstTimeSignupKey) ?? false;
    final isOnboardingComplete = prefs.getBool(_shopperOnboardingKey) ?? false;
    
    return isFirstTime && !isOnboardingComplete;
  }

  /// Clear the first time signup flag
  static Future<void> clearFirstTimeSignupFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shopperFirstTimeSignupKey);
  }

  /// Check if vendor onboarding has been completed
  static Future<bool> isVendorOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vendorOnboardingKey) ?? false;
  }

  /// Mark vendor onboarding as completed
  static Future<void> markVendorOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vendorOnboardingKey, true);
  }

  /// Reset vendor onboarding (for testing or re-showing)
  static Future<void> resetVendorOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_vendorOnboardingKey);
  }

  /// Reset all onboarding states
  static Future<void> resetAllOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_organizerOnboardingKey);
    await prefs.remove(_shopperOnboardingKey);
    await prefs.remove(_vendorOnboardingKey);
    await prefs.remove(_shopperFirstTimeSignupKey);
  }
}