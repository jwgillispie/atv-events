import 'package:flutter/material.dart';

/// HiPop Marketplace Color System
/// A sophisticated nature-inspired palette optimized for marketplace conversion
/// Based on: https://coolors.co/558b6e-6f9686-88a09e-7c767e-704c5e-946c7e-b88c9e-f1c8db-f3d2e1
/// Designed for trust, accessibility (WCAG 2.1 AA/AAA compliant), and user engagement
class HiPopColors {
  // ======= Primary Brand Colors =======
  /// Deep Sage (#558B6E) - Primary brand color, main CTAs
  static const Color primaryDeepSage = Color(0xFF558B6E);
  
  /// Deep Sage variations for interactive states
  static const Color primaryDeepSageLight = Color(0xFF6FA589);
  static const Color primaryDeepSageDark = Color(0xFF3D6450);
  static const Color primaryDeepSageSoft = Color(0xFF669C7F);
  
  // ======= Secondary Colors =======
  /// Soft Sage (#6F9686) - Navigation bars, selected states
  static const Color secondarySoftSage = Color(0xFF6F9686);
  static const Color secondarySoftSageLight = Color(0xFF8BAFA1);
  static const Color secondarySoftSageDark = Color(0xFF567365);
  
  // ======= Background Colors =======
  /// Muted Blue-Gray (#88A09E) - Main background
  static const Color backgroundMutedGray = Color(0xFF88A09E);
  /// Warm Gray (#7C767E) - Secondary background, disabled states
  static const Color backgroundWarmGray = Color(0xFF7C767E);
  
  // ======= Accent Colors =======
  /// Dusty Plum (#704C5E) - Danger/delete actions
  static const Color accentDustyPlum = Color(0xFF704C5E);
  static const Color accentDustyPlumLight = Color(0xFF8B6375);
  static const Color accentDustyPlumDark = Color(0xFF553745);
  
  /// Mauve (#946C7E) - Secondary navigation, tabs
  static const Color accentMauve = Color(0xFF946C7E);
  static const Color accentMauveLight = Color(0xFFAB8495);
  static const Color accentMauveDark = Color(0xFF735563);
  
  /// Dusty Rose (#B88C9E) - Hover states, subtle highlights
  static const Color accentDustyRose = Color(0xFFB88C9E);
  static const Color accentDustyRoseLight = Color(0xFFCCA5B5);
  static const Color accentDustyRoseDark = Color(0xFF9B7082);
  
  // ======= Content Surface Colors =======
  /// Soft Pink (#F1C8DB) - Card backgrounds, content areas
  static const Color surfaceSoftPink = Color(0xFFF1C8DB);
  /// Pale Pink (#F3D2E1) - Lightest backgrounds, input fields
  static const Color surfacePalePink = Color(0xFFF3D2E1);
  
  // ======= Semantic Colors =======
  /// Success states - using Deep Sage for consistency
  static const Color successGreen = Color(0xFF558B6E);
  static const Color successGreenLight = Color(0xFF6FA589);
  static const Color successGreenDark = Color(0xFF3D6450);
  
  /// Warning states - warm amber tone
  static const Color warningAmber = Color(0xFFE8A87C);
  static const Color warningAmberLight = Color(0xFFF0C19E);
  static const Color warningAmberDark = Color(0xFFD08C5A);
  
  /// Error states - using Dusty Plum
  static const Color errorPlum = Color(0xFF704C5E);
  static const Color errorPlumLight = Color(0xFF8B6375);
  static const Color errorPlumDark = Color(0xFF553745);
  
  /// Info states - using Muted Blue-Gray
  static const Color infoBlueGray = Color(0xFF88A09E);
  static const Color infoBlueGrayLight = Color(0xFFA3B8B6);
  static const Color infoBlueGrayDark = Color(0xFF6D8280);
  
  // ======= Surface Colors - Light Theme =======
  static const Color lightBackground = Color(0xFFFAFBFC);  // Very soft neutral white
  static const Color lightSurface = Color(0xFFF3D2E1);     // Pale Pink for cards
  static const Color lightSurfaceVariant = Color(0xFFF1C8DB); // Soft Pink variant
  static const Color lightSurfaceElevated = Color(0xFFFDEFF5); // Elevated components
  
  // ======= Surface Colors - Dark Theme =======
  static const Color darkBackground = Color(0xFF1A1418);    // Very dark plum
  static const Color darkSurface = Color(0xFF2A2025);       // Dark surface
  static const Color darkSurfaceVariant = Color(0xFF352B30); // Elevated dark surface
  static const Color darkSurfaceElevated = Color(0xFF403539); // Higher elevation
  
  // ======= Text Colors - Light Theme =======
  static const Color lightTextPrimary = Color(0xFF2A2527);   // Almost black, warm tinted
  static const Color lightTextSecondary = Color(0xFF5C5458); // Medium gray-plum
  static const Color lightTextTertiary = Color(0xFF8B8289);  // Light gray-plum
  static const Color lightTextDisabled = Color(0xFFB8B0B6);  // Disabled state
  
  // ======= Text Colors - Dark Theme =======
  static const Color darkTextPrimary = Color(0xFFF8F4F6);    // Off-white with warm tint
  static const Color darkTextSecondary = Color(0xFFD6CED3);  // Light gray
  static const Color darkTextTertiary = Color(0xFFB0A8AD);   // Medium gray
  static const Color darkTextDisabled = Color(0xFF8A8287);   // Disabled state
  
  // ======= Border & Divider Colors =======
  static const Color lightBorder = Color(0xFFE8D4E0);        // Light theme borders
  static const Color lightDivider = Color(0xFFF0E0EA);       // Light theme dividers
  static const Color darkBorder = Color(0xFF4A3F44);         // Dark theme borders
  static const Color darkDivider = Color(0xFF3A3036);        // Dark theme dividers
  
  // ======= Special Effect Colors =======
  /// Overlay colors for modals and sheets
  static const Color lightOverlay = Color(0x802A2527);       // 50% opacity dark
  static const Color darkOverlay = Color(0x80000000);        // 50% opacity black
  
  /// Shadow colors
  static const Color lightShadow = Color(0x1A558B6E);        // 10% primary
  static const Color darkShadow = Color(0x40000000);         // 25% black
  
  /// Shimmer/Loading effects
  static const Color lightShimmer = Color(0x1F6F9686);       // Subtle sage shimmer
  static const Color darkShimmer = Color(0x1F8BAFA1);        // Subtle light sage shimmer
  
  // ======= Interactive State Colors =======
  /// Hover states
  static const Color lightHover = Color(0x0A558B6E);         // 4% primary
  static const Color darkHover = Color(0x146F9686);          // 8% soft sage
  
  /// Focus states
  static const Color lightFocus = Color(0x1F558B6E);         // 12% primary
  static const Color darkFocus = Color(0x296F9686);          // 16% soft sage
  
  /// Selected states
  static const Color lightSelected = Color(0x14558B6E);      // 8% primary
  static const Color darkSelected = Color(0x1F6F9686);       // 12% soft sage
  
  /// Pressed/Active states
  static const Color lightPressed = Color(0x29558B6E);       // 16% primary
  static const Color darkPressed = Color(0x3D6F9686);        // 24% soft sage
  
  // ======= User Role Colors =======
  /// Vendor-specific accent - using Mauve
  static const Color vendorAccent = Color(0xFF946C7E);
  static const Color vendorAccentLight = Color(0xFFAB8495);
  static const Color vendorAccentDark = Color(0xFF735563);
  
  /// Organizer-specific accent - using Deep Sage
  static const Color organizerAccent = Color(0xFF558B6E);
  static const Color organizerAccentLight = Color(0xFF6FA589);
  static const Color organizerAccentDark = Color(0xFF3D6450);
  
  /// Shopper-specific accent - using Soft Sage
  static const Color shopperAccent = Color(0xFF6F9686);
  static const Color shopperAccentLight = Color(0xFF8BAFA1);
  static const Color shopperAccentDark = Color(0xFF567365);
  
  // ======= Premium/Subscription Colors =======
  /// Premium gold with warm undertones
  static const Color premiumGold = Color(0xFFD4A574);
  static const Color premiumGoldLight = Color(0xFFE2BA8F);
  static const Color premiumGoldDark = Color(0xFFB8925F);
  static const Color premiumGoldSoft = Color(0xFFDDB585);
  
  // ======= Gradients =======
  /// Primary brand gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeepSage, secondarySoftSage],
  );
  
  /// Accent gradient for CTAs
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDeepSage, primaryDeepSageLight],
  );
  
  /// Success gradient
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [successGreen, successGreenLight],
  );
  
  /// Premium gradient
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [premiumGold, premiumGoldLight],
    stops: [0.0, 1.0],
  );
  
  /// Surface gradient for cards
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      surfacePalePink,
      surfaceSoftPink,
    ],
  );
  
  /// Navigation gradient
  static const LinearGradient navigationGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      secondarySoftSage,
      accentMauve,
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