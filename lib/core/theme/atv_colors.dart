import 'package:flutter/material.dart';

/// ATV Events Color System
/// A clean, professional black and white palette for Atlanta Tech Village
/// Designed for clarity, accessibility (WCAG 2.1 AAA compliant), and modern aesthetics
class HiPopColors {
  // ======= Primary Brand Colors =======
  /// Pure Black (#000000) - Primary brand color, main CTAs, text
  static const Color primaryDeepSage = Color(0xFF000000);

  /// Black variations for interactive states
  static const Color primaryDeepSageLight = Color(0xFF333333);
  static const Color primaryDeepSageDark = Color(0xFF000000);
  static const Color primaryDeepSageSoft = Color(0xFF1A1A1A);

  // ======= Secondary Colors =======
  /// Dark Gray (#333333) - Navigation bars, selected states
  static const Color secondarySoftSage = Color(0xFF333333);
  static const Color secondarySoftSageLight = Color(0xFF666666);
  static const Color secondarySoftSageDark = Color(0xFF1A1A1A);
  
  // ======= Background Colors =======
  /// Light Gray (#F5F5F5) - Main background
  static const Color backgroundMutedGray = Color(0xFFF5F5F5);
  /// Medium Gray (#CCCCCC) - Secondary background, disabled states
  static const Color backgroundWarmGray = Color(0xFFCCCCCC);

  // ======= Accent Colors =======
  /// Dark Gray (#1A1A1A) - Danger/delete actions
  static const Color accentDustyPlum = Color(0xFF1A1A1A);
  static const Color accentDustyPlumLight = Color(0xFF333333);
  static const Color accentDustyPlumDark = Color(0xFF000000);

  /// Medium Gray (#666666) - Secondary navigation, tabs
  static const Color accentMauve = Color(0xFF666666);
  static const Color accentMauveLight = Color(0xFF999999);
  static const Color accentMauveDark = Color(0xFF333333);

  /// Light Gray (#999999) - Hover states, subtle highlights
  static const Color accentDustyRose = Color(0xFF999999);
  static const Color accentDustyRoseLight = Color(0xFFCCCCCC);
  static const Color accentDustyRoseDark = Color(0xFF666666);

  // ======= Content Surface Colors =======
  /// White (#FFFFFF) - Card backgrounds, content areas
  static const Color surfaceSoftPink = Color(0xFFFFFFFF);
  /// Light Gray (#FAFAFA) - Lightest backgrounds, input fields
  static const Color surfacePalePink = Color(0xFFFAFAFA);
  
  // ======= Semantic Colors =======
  /// Success states - using black for consistency
  static const Color successGreen = Color(0xFF000000);
  static const Color successGreenLight = Color(0xFF333333);
  static const Color successGreenDark = Color(0xFF000000);

  /// Warning states - using dark gray
  static const Color warningAmber = Color(0xFF666666);
  static const Color warningAmberLight = Color(0xFF999999);
  static const Color warningAmberDark = Color(0xFF333333);

  /// Error states - using black
  static const Color errorPlum = Color(0xFF000000);
  static const Color errorPlumLight = Color(0xFF333333);
  static const Color errorPlumDark = Color(0xFF000000);

  /// Info states - using medium gray
  static const Color infoBlueGray = Color(0xFF666666);
  static const Color infoBlueGrayLight = Color(0xFF999999);
  static const Color infoBlueGrayDark = Color(0xFF333333);
  
  // ======= Surface Colors - Light Theme =======
  static const Color lightBackground = Color(0xFFFFFFFF);    // Pure white
  static const Color lightSurface = Color(0xFFFAFAFA);       // Very light gray for cards
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5); // Light gray variant
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF); // Elevated components (white)

  // ======= Surface Colors - Dark Theme =======
  static const Color darkBackground = Color(0xFF000000);     // Pure black
  static const Color darkSurface = Color(0xFF1A1A1A);        // Very dark gray
  static const Color darkSurfaceVariant = Color(0xFF333333); // Dark gray variant
  static const Color darkSurfaceElevated = Color(0xFF4D4D4D); // Higher elevation

  // ======= Text Colors - Light Theme =======
  static const Color lightTextPrimary = Color(0xFF000000);   // Pure black
  static const Color lightTextSecondary = Color(0xFF333333); // Dark gray
  static const Color lightTextTertiary = Color(0xFF666666);  // Medium gray
  static const Color lightTextDisabled = Color(0xFFCCCCCC);  // Light gray disabled

  // ======= Text Colors - Dark Theme =======
  static const Color darkTextPrimary = Color(0xFFFFFFFF);    // Pure white
  static const Color darkTextSecondary = Color(0xFFCCCCCC);  // Light gray
  static const Color darkTextTertiary = Color(0xFF999999);   // Medium gray
  static const Color darkTextDisabled = Color(0xFF666666);   // Disabled state

  // ======= Border & Divider Colors =======
  static const Color lightBorder = Color(0xFFE0E0E0);        // Light gray borders
  static const Color lightDivider = Color(0xFFF0F0F0);       // Very light gray dividers
  static const Color darkBorder = Color(0xFF333333);         // Dark gray borders
  static const Color darkDivider = Color(0xFF1A1A1A);        // Very dark gray dividers
  
  // ======= Special Effect Colors =======
  /// Overlay colors for modals and sheets
  static const Color lightOverlay = Color(0x80000000);       // 50% opacity black
  static const Color darkOverlay = Color(0x80000000);        // 50% opacity black

  /// Shadow colors
  static const Color lightShadow = Color(0x1A000000);        // 10% black
  static const Color darkShadow = Color(0x40000000);         // 25% black

  /// Shimmer/Loading effects
  static const Color lightShimmer = Color(0x1FE0E0E0);       // Subtle gray shimmer
  static const Color darkShimmer = Color(0x1F333333);        // Subtle dark shimmer

  // ======= Interactive State Colors =======
  /// Hover states
  static const Color lightHover = Color(0x0A000000);         // 4% black
  static const Color darkHover = Color(0x14FFFFFF);          // 8% white

  /// Focus states
  static const Color lightFocus = Color(0x1F000000);         // 12% black
  static const Color darkFocus = Color(0x29FFFFFF);          // 16% white

  /// Selected states
  static const Color lightSelected = Color(0x14000000);      // 8% black
  static const Color darkSelected = Color(0x1FFFFFFF);       // 12% white

  /// Pressed/Active states
  static const Color lightPressed = Color(0x29000000);       // 16% black
  static const Color darkPressed = Color(0x3DFFFFFF);        // 24% white

  // ======= User Role Colors =======
  /// Vendor-specific accent - not used in ATV Events (removed vendors)
  static const Color vendorAccent = Color(0xFF666666);
  static const Color vendorAccentLight = Color(0xFF999999);
  static const Color vendorAccentDark = Color(0xFF333333);

  /// Organizer-specific accent - using black
  static const Color organizerAccent = Color(0xFF000000);
  static const Color organizerAccentLight = Color(0xFF333333);
  static const Color organizerAccentDark = Color(0xFF000000);

  /// Shopper-specific accent - using medium gray
  static const Color shopperAccent = Color(0xFF666666);
  static const Color shopperAccentLight = Color(0xFF999999);
  static const Color shopperAccentDark = Color(0xFF333333);

  // ======= Premium/Subscription Colors =======
  /// Premium - not used in ATV Events (removed premium features)
  static const Color premiumGold = Color(0xFF666666);
  static const Color premiumGoldLight = Color(0xFF999999);
  static const Color premiumGoldDark = Color(0xFF333333);
  static const Color premiumGoldSoft = Color(0xFF808080);
  
  // ======= Gradients =======
  /// Primary brand gradient - black to dark gray
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF333333)],
  );

  /// Accent gradient for CTAs
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF1A1A1A)],
  );

  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF333333)],
  );

  /// Premium gradient - not used in ATV Events
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF666666), Color(0xFF999999)],
    stops: [0.0, 1.0],
  );

  /// Surface gradient for cards - white to light gray
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFAFAFA),
    ],
  );

  /// Navigation gradient
  static const LinearGradient navigationGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF000000),
      Color(0xFF1A1A1A),
    ],
  );
  
  // ======= Opacity Variants =======
  /// Primary color with various opacities
  static Color primaryOpacity(double opacity) => 
    primaryDeepSage.withOpacity( opacity);
  
  /// Secondary color with various opacities
  static Color secondaryOpacity(double opacity) => 
    secondarySoftSage.withOpacity( opacity);
  
  /// Accent color with various opacities
  static Color accentOpacity(double opacity) => 
    accentMauve.withOpacity( opacity);
  
  // ======= Utility Methods =======
  /// Get appropriate text color for a background
  static Color getTextColorFor(Color background) {
    return background.computeLuminance() > 0.5 
      ? lightTextPrimary 
      : darkTextPrimary;
  }
  
  /// Check if color meets WCAG contrast requirements
  static bool meetsContrastGuidelines(Color foreground, Color background) {
    final double contrast = _calculateContrast(foreground, background);
    return contrast >= 4.5; // WCAG AA standard for normal text
  }
  
  /// Check if color meets WCAG AAA contrast requirements
  static bool meetsContrastGuidelinesAAA(Color foreground, Color background) {
    final double contrast = _calculateContrast(foreground, background);
    return contrast >= 7.0; // WCAG AAA standard for normal text
  }
  
  static double _calculateContrast(Color foreground, Color background) {
    final l1 = foreground.computeLuminance();
    final l2 = background.computeLuminance();
    final lMax = l1 > l2 ? l1 : l2;
    final lMin = l1 < l2 ? l1 : l2;
    return (lMax + 0.05) / (lMin + 0.05);
  }
  
  /// Get role-specific accent color
  static Color getRoleAccent(String role, {bool isDark = false}) {
    switch (role.toLowerCase()) {
      case 'vendor':
        return isDark ? vendorAccentLight : vendorAccent;
      case 'organizer':
        return isDark ? organizerAccentLight : organizerAccent;
      case 'shopper':
        return isDark ? shopperAccentLight : shopperAccent;
      default:
        return isDark ? primaryDeepSageLight : primaryDeepSage;
    }
  }
}