import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'hipop_colors.dart';

/// HiPop Marketplace Theme System
/// Material Design 3 compliant theme with nature-inspired colors
/// Optimized for marketplace conversion and user trust
class HiPopTheme {
  
  // ======= Light Theme Configuration =======
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // ======= Color Scheme =======
      colorScheme: const ColorScheme.light(
        primary: HiPopColors.primaryDeepSage,
        onPrimary: Colors.white,
        primaryContainer: HiPopColors.primaryDeepSageLight,
        onPrimaryContainer: HiPopColors.darkTextPrimary,
        
        secondary: HiPopColors.secondarySoftSage,
        onSecondary: Colors.white,
        secondaryContainer: HiPopColors.secondarySoftSageLight,
        onSecondaryContainer: HiPopColors.primaryDeepSageDark,
        
        tertiary: HiPopColors.accentMauve,
        onTertiary: Colors.white,
        tertiaryContainer: HiPopColors.accentMauveLight,
        onTertiaryContainer: HiPopColors.accentMauveDark,
        
        error: HiPopColors.errorPlum,
        onError: Colors.white,
        errorContainer: HiPopColors.errorPlumLight,
        onErrorContainer: HiPopColors.errorPlumDark,
        
        surface: HiPopColors.lightSurface,
        onSurface: HiPopColors.lightTextPrimary,
        surfaceContainerHighest: HiPopColors.lightSurfaceVariant,
        onSurfaceVariant: HiPopColors.lightTextSecondary,
        
        outline: HiPopColors.lightBorder,
        outlineVariant: HiPopColors.lightDivider,
        
        shadow: HiPopColors.lightShadow,
        scrim: HiPopColors.lightOverlay,
      ),
      
      // ======= Core Colors =======
      scaffoldBackgroundColor: HiPopColors.backgroundMutedGray.withOpacity( 0.1),
      primaryColor: HiPopColors.primaryDeepSage,
      canvasColor: HiPopColors.lightBackground,
      dividerColor: HiPopColors.lightDivider,
      
      // ======= Typography =======
      textTheme: _buildTextTheme(base.textTheme, Brightness.light),
      primaryTextTheme: _buildTextTheme(base.primaryTextTheme, Brightness.light),
      
      // ======= App Bar Theme =======
      appBarTheme: AppBarTheme(
        backgroundColor: HiPopColors.lightSurface,
        foregroundColor: HiPopColors.lightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HiPopColors.lightTextPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: HiPopColors.lightTextPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: HiPopColors.lightTextSecondary,
          size: 24,
        ),
        shadowColor: HiPopColors.lightShadow,
        surfaceTintColor: Colors.transparent,
      ),
      
      // ======= Card Theme =======
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: HiPopColors.lightBorder,
            width: 1,
          ),
        ),
        color: HiPopColors.lightSurface,
        shadowColor: HiPopColors.lightShadow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      
      // ======= Elevated Button Theme =======
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HiPopColors.primaryDeepSage,
          foregroundColor: Colors.white,
          disabledBackgroundColor: HiPopColors.backgroundWarmGray,
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return HiPopColors.primaryDeepSageDark.withOpacity( 0.1);
            }
            if (states.contains(WidgetState.hovered)) {
              return HiPopColors.accentDustyRose.withOpacity( 0.08);
            }
            return null;
          }),
        ),
      ),
      
      // ======= Text Button Theme =======
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HiPopColors.primaryDeepSage,
          disabledForegroundColor: HiPopColors.lightTextDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(64, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // ======= Outlined Button Theme =======
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HiPopColors.primaryDeepSage,
          disabledForegroundColor: HiPopColors.lightTextDisabled,
          side: const BorderSide(
            color: HiPopColors.primaryDeepSage,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // ======= Input Decoration Theme =======
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HiPopColors.lightSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.lightBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.lightBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.primaryDeepSage,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.errorPlum,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.errorPlum,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: HiPopColors.lightBorder.withOpacity( 0.5),
            width: 1,
          ),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.lightTextSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.lightTextTertiary,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: HiPopColors.errorPlum,
        ),
        prefixIconColor: HiPopColors.lightTextSecondary,
        suffixIconColor: HiPopColors.lightTextSecondary,
      ),
      
      // ======= Icon Theme =======
      iconTheme: const IconThemeData(
        color: HiPopColors.lightTextPrimary,
        size: 24,
      ),
      
      // ======= Icon Button Theme =======
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: HiPopColors.lightTextPrimary,
          disabledForegroundColor: HiPopColors.lightTextDisabled,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(8),
        ),
      ),
      
      // ======= Floating Action Button Theme =======
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HiPopColors.primaryDeepSage,
        foregroundColor: Colors.white,
        elevation: 4,
        // Removed CircleBorder() and size constraints to allow extended FABs
        // Extended FABs will use their default pill shape
      ),
      
      // ======= Bottom Navigation Bar Theme =======
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: HiPopColors.secondarySoftSage,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
      ),
      
      // ======= Navigation Bar Theme (Material 3) =======
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: HiPopColors.accentMauve,
        indicatorColor: Colors.white.withOpacity( 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            );
          }
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: Colors.white,
              size: 24,
            );
          }
          return const IconThemeData(
            color: Colors.white70,
            size: 24,
          );
        }),
        height: 64,
      ),
      
      // ======= Chip Theme =======
      chipTheme: ChipThemeData(
        backgroundColor: HiPopColors.lightSurfaceVariant,
        deleteIconColor: HiPopColors.lightTextSecondary,
        disabledColor: HiPopColors.lightTextDisabled.withOpacity( 0.12),
        selectedColor: HiPopColors.primaryDeepSage.withOpacity( 0.15),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.lightTextPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.lightTextPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(
            color: HiPopColors.lightBorder,
            width: 0.5,
          ),
        ),
      ),
      
      // ======= Dialog Theme =======
      dialogTheme: DialogThemeData(
        backgroundColor: HiPopColors.lightSurface,
        elevation: 24,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HiPopColors.lightTextPrimary,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.lightTextSecondary,
          height: 1.5,
        ),
      ),
      
      // ======= Snackbar Theme =======
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HiPopColors.primaryDeepSageDark,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        actionTextColor: HiPopColors.premiumGoldLight,
      ),
      
      // ======= Tab Bar Theme =======
      tabBarTheme: TabBarThemeData(
        labelColor: HiPopColors.primaryDeepSage,
        unselectedLabelColor: HiPopColors.lightTextTertiary,
        indicatorColor: HiPopColors.primaryDeepSage,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // ======= Divider Theme =======
      dividerTheme: const DividerThemeData(
        color: HiPopColors.lightDivider,
        thickness: 1,
        space: 24,
      ),
      
      // ======= List Tile Theme =======
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: HiPopColors.primaryDeepSage.withOpacity( 0.08),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        iconColor: HiPopColors.lightTextSecondary,
        textColor: HiPopColors.lightTextPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: HiPopColors.lightTextPrimary,
        ),
        subtitleTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.lightTextSecondary,
        ),
      ),
      
      // ======= Switch Theme =======
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return HiPopColors.primaryDeepSage;
          }
          return HiPopColors.lightTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return HiPopColors.primaryDeepSage.withOpacity( 0.5);
          }
          return HiPopColors.lightBorder;
        }),
      ),
      
      // ======= Progress Indicator Theme =======
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HiPopColors.primaryDeepSage,
        linearTrackColor: HiPopColors.lightBorder,
        circularTrackColor: HiPopColors.lightBorder,
      ),
      
      // ======= Badge Theme =======
      badgeTheme: const BadgeThemeData(
        backgroundColor: HiPopColors.primaryDeepSage,
        textColor: Colors.white,
      ),
    );
  }
  
  // ======= Dark Theme Configuration =======
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // ======= Color Scheme =======
      colorScheme: const ColorScheme.dark(
        primary: HiPopColors.secondarySoftSage,
        onPrimary: HiPopColors.darkTextPrimary,
        primaryContainer: HiPopColors.primaryDeepSageDark,
        onPrimaryContainer: HiPopColors.secondarySoftSageLight,
        
        secondary: HiPopColors.accentMauve,
        onSecondary: Colors.white,
        secondaryContainer: HiPopColors.accentMauveDark,
        onSecondaryContainer: HiPopColors.accentMauveLight,
        
        tertiary: HiPopColors.premiumGold,
        onTertiary: HiPopColors.darkTextPrimary,
        tertiaryContainer: HiPopColors.premiumGoldDark,
        onTertiaryContainer: HiPopColors.premiumGoldLight,
        
        error: HiPopColors.errorPlumLight,
        onError: HiPopColors.darkTextPrimary,
        errorContainer: HiPopColors.errorPlumDark,
        onErrorContainer: HiPopColors.errorPlumLight,
        
        surface: HiPopColors.darkSurface,
        onSurface: HiPopColors.darkTextPrimary,
        surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
        onSurfaceVariant: HiPopColors.darkTextSecondary,
        
        outline: HiPopColors.darkBorder,
        outlineVariant: HiPopColors.darkDivider,
        
        shadow: HiPopColors.darkShadow,
        scrim: HiPopColors.darkOverlay,
      ),
      
      // ======= Core Colors =======
      scaffoldBackgroundColor: HiPopColors.darkBackground,
      primaryColor: HiPopColors.secondarySoftSage,
      canvasColor: HiPopColors.darkBackground,
      dividerColor: HiPopColors.darkDivider,
      
      // ======= Typography =======
      textTheme: _buildTextTheme(base.textTheme, Brightness.dark),
      primaryTextTheme: _buildTextTheme(base.primaryTextTheme, Brightness.dark),
      
      // ======= App Bar Theme =======
      appBarTheme: AppBarTheme(
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: HiPopColors.darkTextPrimary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(
          color: HiPopColors.darkTextPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: HiPopColors.darkTextSecondary,
          size: 24,
        ),
        shadowColor: HiPopColors.darkShadow,
        surfaceTintColor: Colors.transparent,
      ),
      
      // ======= Card Theme =======
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: HiPopColors.darkBorder,
            width: 1,
          ),
        ),
        color: HiPopColors.darkSurface,
        shadowColor: HiPopColors.darkShadow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAliasWithSaveLayer,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      
      // ======= Elevated Button Theme =======
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HiPopColors.secondarySoftSage,
          foregroundColor: HiPopColors.darkTextPrimary,
          disabledBackgroundColor: HiPopColors.backgroundWarmGray,
          disabledForegroundColor: HiPopColors.darkTextDisabled,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return HiPopColors.secondarySoftSageLight.withOpacity( 0.2);
            }
            if (states.contains(WidgetState.hovered)) {
              return HiPopColors.accentMauveLight.withOpacity( 0.1);
            }
            return null;
          }),
        ),
      ),
      
      // ======= Text Button Theme =======
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HiPopColors.secondarySoftSage,
          disabledForegroundColor: HiPopColors.darkTextDisabled,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          minimumSize: const Size(64, 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      
      // ======= Input Decoration Theme =======
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HiPopColors.darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.darkBorder,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.darkBorder,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.secondarySoftSage,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.errorPlumLight,
            width: 1,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: HiPopColors.errorPlumLight,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: HiPopColors.darkBorder.withOpacity( 0.5),
            width: 1,
          ),
        ),
        labelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.darkTextSecondary,
        ),
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: HiPopColors.darkTextTertiary,
        ),
        errorStyle: GoogleFonts.inter(
          fontSize: 12,
          color: HiPopColors.errorPlumLight,
        ),
        prefixIconColor: HiPopColors.darkTextSecondary,
        suffixIconColor: HiPopColors.darkTextSecondary,
      ),
      
      // ======= Icon Theme =======
      iconTheme: const IconThemeData(
        color: HiPopColors.darkTextPrimary,
        size: 24,
      ),
    );
  }
  
  // ======= Text Theme Builder =======
  static TextTheme _buildTextTheme(TextTheme base, Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color primaryText = isDark ? HiPopColors.darkTextPrimary : HiPopColors.lightTextPrimary;
    final Color secondaryText = isDark ? HiPopColors.darkTextSecondary : HiPopColors.lightTextSecondary;
    
    return TextTheme(
      // Display styles - for large headers
      displayLarge: GoogleFonts.poppins(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.25,
        color: primaryText,
        height: 1.12,
      ),
      displayMedium: GoogleFonts.poppins(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryText,
        height: 1.16,
      ),
      displaySmall: GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: primaryText,
        height: 1.22,
      ),
      
      // Headline styles - for section headers
      headlineLarge: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primaryText,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primaryText,
        height: 1.29,
      ),
      headlineSmall: GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primaryText,
        height: 1.33,
      ),
      
      // Title styles - for cards and lists
      titleLarge: GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: primaryText,
        height: 1.27,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
        color: primaryText,
        height: 1.5,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryText,
        height: 1.43,
      ),
      
      // Body styles - for content
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
        color: primaryText,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        color: primaryText,
        height: 1.43,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.4,
        color: secondaryText,
        height: 1.33,
      ),
      
      // Label styles - for buttons and chips
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: primaryText,
        height: 1.43,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: primaryText,
        height: 1.33,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: secondaryText,
        height: 1.45,
      ),
    );
  }
}

/// Theme Extension for custom properties
extension HiPopThemeExtension on ThemeData {
  /// Get vendor-specific colors
  Color get vendorAccent => brightness == Brightness.light
      ? HiPopColors.vendorAccent
      : HiPopColors.vendorAccentLight;
  
  /// Get organizer-specific colors
  Color get organizerAccent => brightness == Brightness.light
      ? HiPopColors.organizerAccent
      : HiPopColors.organizerAccentLight;
  
  /// Get shopper-specific colors
  Color get shopperAccent => brightness == Brightness.light
      ? HiPopColors.shopperAccent
      : HiPopColors.shopperAccentLight;
  
  /// Get premium/gold colors
  Color get premiumColor => brightness == Brightness.light
      ? HiPopColors.premiumGold
      : HiPopColors.premiumGoldLight;
  
  /// Get background muted gray
  Color get backgroundMuted => HiPopColors.backgroundMutedGray;
  
  /// Get background warm gray
  Color get backgroundWarm => HiPopColors.backgroundWarmGray;
}