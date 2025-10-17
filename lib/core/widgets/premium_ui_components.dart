import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized premium UI components for consistent design across the app
/// Ensures proper text visibility and cohesive theming for marketplace screens
class PremiumUIComponents {
  
  /// Standard premium badge with mauve diamond icon
  static Widget premiumBadge({
    double size = 20,
    EdgeInsetsGeometry padding = const EdgeInsets.all(6),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: HiPopColors.accentMauve.withOpacity( 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.diamond,
        color: HiPopColors.accentMauve,
        size: size,
      ),
    );
  }
  
  /// Premium feature card with consistent styling
  static Widget premiumFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
            ? HiPopColors.primaryDeepSage.withOpacity( 0.05)
            : HiPopColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
              ? HiPopColors.primaryDeepSage 
              : HiPopColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: HiPopColors.lightShadow.withOpacity( 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: HiPopColors.primaryDeepSage,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: HiPopColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: HiPopColors.primaryDeepSage,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
  
  /// Success checkmark item for feature lists
  static Widget featureCheckItem({
    required String text,
    Color? checkColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: checkColor ?? HiPopColors.successGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: HiPopColors.lightTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Premium CTA button with gradient background
  static Widget premiumCTAButton({
    required String text,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
    bool fullWidth = true,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HiPopColors.primaryDeepSage,
            HiPopColors.secondarySoftSage,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: HiPopColors.primaryDeepSage.withOpacity( 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Center(
              child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
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
  
  /// Info banner for premium features
  static Widget infoBanner({
    required String message,
    IconData icon = Icons.info_outline,
    Color? backgroundColor,
    Color? iconColor,
    Color? textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? HiPopColors.darkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.accentMauve.withOpacity( 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor ?? HiPopColors.accentMauve,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: textColor ?? HiPopColors.lightTextPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Premium tier selection card
  static Widget tierSelectionCard({
    required String title,
    required String price,
    required String description,
    required List<String> features,
    bool isSelected = false,
    bool isRecommended = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected 
            ? HiPopColors.primaryDeepSage.withOpacity( 0.05)
            : HiPopColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
              ? HiPopColors.primaryDeepSage 
              : HiPopColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: HiPopColors.lightShadow.withOpacity( 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isRecommended)
              Positioned(
                top: 0,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: HiPopColors.warningAmber,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Text(
                    'RECOMMENDED',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected 
                            ? HiPopColors.primaryDeepSage 
                            : HiPopColors.lightTextPrimary,
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: HiPopColors.primaryDeepSage,
                          size: 24,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: HiPopColors.lightTextSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        price,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.primaryDeepSage,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '/month',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: HiPopColors.lightTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Key Features:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: HiPopColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...features.take(4).map((feature) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check,
                            color: HiPopColors.successGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: HiPopColors.lightTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (features.length > 4)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${features.length - 4} more features',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: HiPopColors.lightTextTertiary,
                          fontStyle: FontStyle.italic,
                        ),
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
  
  /// Market discovery filter chip with consistent styling
  static Widget filterChip({
    required String label,
    required IconData icon,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: onTap != null ? (_) => onTap() : null,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: HiPopColors.primaryDeepSage.withOpacity( 0.2),
      checkmarkColor: HiPopColors.primaryDeepSage,
      backgroundColor: HiPopColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected 
            ? HiPopColors.primaryDeepSage 
            : HiPopColors.lightBorder,
        ),
      ),
    );
  }
  
  /// Metric display chip for analytics and discovery
  static Widget metricChip({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final chipColor = color ?? HiPopColors.primaryDeepSage;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: chipColor.withOpacity( 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: chipColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}