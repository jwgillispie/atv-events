/// Application-wide constants
class AppConstants {
  // Private constructor to prevent instantiation
  AppConstants._();

  /// Month names array used throughout the app
  static const List<String> months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  /// Abbreviated month names
  static const List<String> monthsAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Day names used in calendar widgets
  static const List<String> dayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  /// Abbreviated day names
  static const List<String> dayNamesAbbr = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
  ];

  /// Common dialog dimensions
  static const double dialogWidthRatio = 0.9;
  static const double dialogHeightRatio = 0.8;
  static const double dialogPadding = 24.0;

  /// Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  /// Snackbar durations
  static const Duration shortSnackbarDuration = Duration(seconds: 3);
  static const Duration mediumSnackbarDuration = Duration(seconds: 4);
  static const Duration longSnackbarDuration = Duration(seconds: 6);

  /// Common border radius values
  static const double smallBorderRadius = 4.0;
  static const double mediumBorderRadius = 8.0;
  static const double largeBorderRadius = 12.0;
  static const double xlBorderRadius = 16.0;

  /// Common spacing values
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  static const double xlSpacing = 32.0;

  /// Icon sizes
  static const double smallIconSize = 16.0;
  static const double mediumIconSize = 20.0;
  static const double largeIconSize = 24.0;
  static const double xlIconSize = 32.0;

  /// Common text size multipliers
  static const double smallTextMultiplier = 0.8;
  static const double largeTextMultiplier = 1.2;
  static const double xlTextMultiplier = 1.5;

  /// Image upload constraints
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxImageCount = 10;
  static const double imageCompressionQuality = 0.8;

  /// Search and pagination
  static const int defaultPageSize = 20;
  static const int maxSearchResults = 50;
  static const Duration searchDebounceDelay = Duration(milliseconds: 500);

  /// Form validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxBioLength = 1000;

  /// Location settings
  static const double defaultLocationRadius = 25.0; // miles
  static const double maxLocationRadius = 100.0; // miles
  static const double defaultMapZoom = 12.0;

  /// Cache durations
  static const Duration shortCacheDuration = Duration(minutes: 5);
  static const Duration mediumCacheDuration = Duration(minutes: 30);
  static const Duration longCacheDuration = Duration(hours: 24);

  /// Network timeouts
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration mediumTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(seconds: 60);
}

/// Firestore collection names
class FirestoreCollections {
  // Private constructor to prevent instantiation
  FirestoreCollections._();

  static const String users = 'users';
  static const String userProfiles = 'user_profiles';
  static const String markets = 'markets';
  static const String marketSchedules = 'market_schedules';
  static const String vendors = 'vendors';
  static const String managedVendors = 'managed_vendors';
  static const String vendorApplications = 'vendor_applications';
  static const String vendorPosts = 'vendor_posts';
  static const String events = 'events';
  static const String userFavorites = 'user_favorites';
  static const String analytics = 'analytics';
  static const String notifications = 'notifications';
  static const String feedback = 'feedback';
  static const String reports = 'reports';
}

/// Application routes
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String shopperHome = '/shopper';
  static const String vendorDashboard = '/vendor';
  static const String organizerDashboard = '/organizer';
  static const String marketDetails = '/market-details';
  static const String vendorDetails = '/vendor-details';
  static const String eventDetails = '/event-details';
  static const String createMarket = '/create-market';
  static const String createVendor = '/create-vendor';
  static const String createEvent = '/create-event';
  static const String vendorApplications = '/vendor-applications';
  static const String marketManagement = '/market-management';
  static const String vendorManagement = '/vendor-management';
}

/// User roles and types
class UserRoles {
  // Private constructor to prevent instantiation
  UserRoles._();

  static const String shopper = 'shopper';
  static const String vendor = 'vendor';
  static const String organizer = 'organizer';
  static const String admin = 'admin';
}

/// Application status values
class AppStatus {
  // Private constructor to prevent instantiation
  AppStatus._();

  static const String active = 'active';
  static const String inactive = 'inactive';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
  static const String draft = 'draft';
  static const String published = 'published';
  static const String archived = 'archived';
}

/// Asset paths
class AssetPaths {
  // Private constructor to prevent instantiation
  AssetPaths._();

  static const String logoPath = 'assets/images/logo.png';
  static const String placeholderImage = 'assets/images/placeholder.png';
  static const String defaultAvatar = 'assets/images/default_avatar.png';
  static const String marketPlaceholder = 'assets/images/market_placeholder.png';
  static const String vendorPlaceholder = 'assets/images/vendor_placeholder.png';
  static const String eventPlaceholder = 'assets/images/event_placeholder.png';
}

/// Regular expressions for validation
class ValidationPatterns {
  // Private constructor to prevent instantiation
  ValidationPatterns._();

  static const String email = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
  static const String phone = r'^\+?[1-9]\d{1,14}$';
  static const String zipCode = r'^\d{5}(-\d{4})?$';
  static const String website = r'^https?:\/\/.+';
  static const String socialHandle = r'^[a-zA-Z0-9._]+$';
}

/// Error messages
class ErrorMessages {
  // Private constructor to prevent instantiation
  ErrorMessages._();

  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String authError = 'Authentication failed. Please log in again.';
  static const String permissionError = 'You do not have permission to perform this action.';
  static const String notFoundError = 'The requested item was not found.';
  static const String validationError = 'Please check your input and try again.';
  static const String unknownError = 'An unexpected error occurred.';
  
  // Form validation errors
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String invalidWebsite = 'Please enter a valid website URL';
  static const String passwordTooShort = 'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
}

/// Success messages
class SuccessMessages {
  // Private constructor to prevent instantiation
  SuccessMessages._();

  static const String profileUpdated = 'Profile updated successfully';
  static const String marketCreated = 'Market created successfully';
  static const String vendorCreated = 'Vendor created successfully';
  static const String eventCreated = 'Event created successfully';
  static const String applicationSubmitted = 'Application submitted successfully';
  static const String applicationApproved = 'Application approved';
  static const String applicationRejected = 'Application rejected';
  static const String favoriteAdded = 'Added to favorites';
  static const String favoriteRemoved = 'Removed from favorites';
  static const String passwordChanged = 'Password changed successfully';
  static const String emailVerified = 'Email verified successfully';
  static const String loggedOut = 'Logged out successfully';
}