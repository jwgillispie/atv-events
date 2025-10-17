/// UI Constants for consistent spacing, sizing, and layout
/// All values are optimized for performance with const constructors
class UIConstants {
  // Private constructor to prevent instantiation
  UIConstants._();

  // ======= Padding & Spacing Values =======
  /// Extra small spacing - 4.0
  static const double extraSmallSpacing = 4.0;
  
  /// Small spacing - 8.0
  static const double smallSpacing = 8.0;
  
  /// Content spacing (between icon and text) - 12.0
  static const double contentSpacing = 12.0;
  
  /// Default padding - 16.0
  static const double defaultPadding = 16.0;
  
  /// Large spacing - 24.0
  static const double largeSpacing = 24.0;
  
  /// Extra large spacing - 32.0
  static const double extraLargeSpacing = 32.0;

  // ======= Border Radius Values =======
  /// Small border radius - 4.0
  static const double smallBorderRadius = 4.0;
  
  /// Small border radius - 8.0
  static const double mediumBorderRadius = 8.0;
  
  /// Card border radius - 12.0
  static const double cardBorderRadius = 12.0;
  
  /// Tag border radius - 12.0
  static const double tagBorderRadius = 12.0;
  
  /// Large border radius - 16.0
  static const double largeBorderRadius = 16.0;

  // ======= Icon Sizes =======
  /// Extra small icon - 14.0
  static const double iconSizeExtraSmall = 14.0;
  
  /// Small icon - 16.0
  static const double iconSizeSmall = 16.0;
  
  /// Medium icon - 20.0
  static const double iconSizeMedium = 20.0;
  
  /// Default icon - 24.0
  static const double iconSizeDefault = 24.0;
  
  /// Large icon - 32.0
  static const double iconSizeLarge = 32.0;
  
  /// Extra large icon - 64.0
  static const double iconSizeExtraLarge = 64.0;

  // ======= Text Sizes =======
  /// Caption text - 10.0
  static const double textSizeCaption = 10.0;
  
  /// Small text - 12.0
  static const double textSizeSmall = 12.0;
  
  /// Body small text - 13.0
  static const double textSizeBodySmall = 13.0;
  
  /// Body text - 14.0
  static const double textSizeBody = 14.0;
  
  /// Title text - 16.0
  static const double textSizeTitle = 16.0;
  
  /// Large title text - 18.0
  static const double textSizeLargeTitle = 18.0;

  // ======= Component Heights =======
  /// Small button height - 32.0
  static const double smallButtonHeight = 32.0;
  
  /// Default button height - 40.0
  static const double defaultButtonHeight = 40.0;
  
  /// Large button height - 48.0
  static const double largeButtonHeight = 48.0;
  
  /// Card elevation - 2.0
  static const double cardElevation = 2.0;
  
  /// Photo preview height - 200.0
  static const double photoPreviewHeight = 200.0;

  // ======= Opacity Values =======
  /// Disabled opacity - 0.38
  static const double disabledOpacity = 0.38;
  
  /// Hover opacity - 0.04
  static const double hoverOpacity = 0.04;
  
  /// Focus opacity - 0.12
  static const double focusOpacity = 0.12;
  
  /// Selected opacity - 0.08
  static const double selectedOpacity = 0.08;
  
  /// Pressed opacity - 0.16
  static const double pressedOpacity = 0.16;
  
  /// Background icon opacity - 0.1
  static const double backgroundIconOpacity = 0.1;
  
  /// Border opacity - 0.3
  static const double borderOpacity = 0.3;

  // ======= Animation Durations =======
  /// Fast animation - 150ms
  static const Duration fastAnimation = Duration(milliseconds: 150);
  
  /// Default animation - 250ms
  static const Duration defaultAnimation = Duration(milliseconds: 250);
  
  /// Slow animation - 350ms
  static const Duration slowAnimation = Duration(milliseconds: 350);

  // ======= Constraints =======
  /// Minimum button width - 64.0
  static const double minButtonWidth = 64.0;
  
  /// Maximum card width - 600.0
  static const double maxCardWidth = 600.0;
  
  /// Maximum description lines - 2
  static const int maxDescriptionLines = 2;
  
  /// Maximum tags to show - 3
  static const int maxTagsToShow = 3;
}