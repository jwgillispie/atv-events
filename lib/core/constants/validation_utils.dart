/// Utility class for common validation operations
class ValidationUtils {
  /// Validates if an email address is in the correct format
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  /// Validates if a phone number is in the correct format
  static bool isValidPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters
    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    // Check if it has 10 digits (US format) or 11 digits (with country code)
    return digitsOnly.length == 10 || digitsOnly.length == 11;
  }

  /// Validates if a string is not empty or just whitespace
  static bool isNotEmpty(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  /// Validates if a URL is in the correct format
  static bool isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}