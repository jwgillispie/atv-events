import 'package:flutter/material.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:confetti/confetti.dart';
import 'dart:math';

/// Beautiful welcome dialog shown to newly verified vendors and organizers
class WelcomeNotificationDialog extends StatefulWidget {
  final String ceoNotes;
  final String userType;
  final VoidCallback onDismiss;
  
  const WelcomeNotificationDialog({
    super.key,
    required this.ceoNotes,
    required this.userType,
    required this.onDismiss,
  });
  
  static Future<void> show({
    required BuildContext context,
    required String ceoNotes,
    required String userType,
    required VoidCallback onDismiss,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => WelcomeNotificationDialog(
        ceoNotes: ceoNotes,
        userType: userType,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<WelcomeNotificationDialog> createState() => _WelcomeNotificationDialogState();
}

class _WelcomeNotificationDialogState extends State<WelcomeNotificationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    // Scale animation for entrance effect
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    // Fade animation
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    // Initialize confetti controller
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Start animations
    _animationController.forward();
    
    // Start confetti after dialog appears
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  Color get _accentColor {
    return widget.userType == 'vendor' 
      ? HiPopColors.vendorAccent 
      : HiPopColors.organizerAccent;
  }
  
  Color get _accentColorLight {
    return widget.userType == 'vendor' 
      ? HiPopColors.vendorAccentLight 
      : HiPopColors.organizerAccentLight;
  }
  
  IconData get _roleIcon {
    return widget.userType == 'vendor' 
      ? Icons.store 
      : Icons.account_balance;
  }
  
  String get _roleTitle {
    return widget.userType == 'vendor' 
      ? 'Vendor' 
      : 'Market Organizer';
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Stack(
      children: [
        // Main dialog
        Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Dialog(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: 500,
                        maxHeight: screenSize.height * 0.8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDarkMode
                            ? [
                                HiPopColors.darkSurface,
                                HiPopColors.darkSurfaceVariant,
                              ]
                            : [
                                Colors.white,
                                HiPopColors.accentMauve.withOpacity(0.1),
                              ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _accentColor.withOpacity( 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with gradient background
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _accentColor,
                                  _accentColorLight,
                                ],
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Success icon with animation
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 800),
                                  tween: Tween(begin: 0, end: 1),
                                  builder: (context, value, child) {
                                    return Transform.rotate(
                                      angle: value * 2 * pi,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity( 0.95),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity( 0.2),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 50,
                                          color: _accentColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Congratulations text
                                Text(
                                  '🎉 Congratulations! 🎉',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 10,
                                        color: Colors.black.withOpacity( 0.3),
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "You've been accepted!",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity( 0.95),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          
                          // Content section
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Welcome badge
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _accentColor.withOpacity( 0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _accentColor.withOpacity( 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _roleIcon,
                                            size: 20,
                                            color: _accentColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Verified $_roleTitle',
                                            style: TextStyle(
                                              color: _accentColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.verified,
                                            size: 20,
                                            color: _accentColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // CEO message header
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              HiPopColors.premiumGold,
                                              HiPopColors.premiumGoldLight,
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.admin_panel_settings,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Message from HiPop Team',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isDarkMode 
                                                  ? HiPopColors.darkTextPrimary 
                                                  : HiPopColors.lightTextPrimary,
                                              ),
                                            ),
                                            Text(
                                              'Personal welcome note',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode 
                                                  ? HiPopColors.darkTextSecondary 
                                                  : HiPopColors.lightTextSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // CEO notes in a styled container
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                        ? HiPopColors.darkSurfaceElevated.withOpacity( 0.5)
                                        : HiPopColors.accentMauve.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _accentColor.withOpacity( 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.format_quote,
                                          color: _accentColor.withOpacity( 0.5),
                                          size: 24,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          widget.ceoNotes,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            color: isDarkMode 
                                              ? HiPopColors.darkTextPrimary 
                                              : HiPopColors.lightTextPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Icon(
                                            Icons.format_quote,
                                            color: _accentColor.withOpacity( 0.5),
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  
                                  // Welcome message
                                  Text(
                                    "Welcome to the HiPop community! We're excited to have you as part of our marketplace. Your journey starts here, and we're here to support you every step of the way.",
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: isDarkMode 
                                        ? HiPopColors.darkTextSecondary 
                                        : HiPopColors.lightTextSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Action button
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                ? HiPopColors.darkSurface.withOpacity( 0.5)
                                : Colors.grey.shade50,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(24),
                                bottomRight: Radius.circular(24),
                              ),
                            ),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  widget.onDismiss();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _accentColor,
                                  foregroundColor: Colors.white,
                                  elevation: 3,
                                  shadowColor: _accentColor.withOpacity( 0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Let's Get Started!",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Confetti overlay
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [
              _accentColor,
              _accentColorLight,
              HiPopColors.premiumGold,
              HiPopColors.premiumGoldLight,
              HiPopColors.successGreen,
            ],
            numberOfParticles: 30,
            gravity: 0.1,
            emissionFrequency: 0.05,
            blastDirection: pi / 2,
          ),
        ),
      ],
    );
  }
}