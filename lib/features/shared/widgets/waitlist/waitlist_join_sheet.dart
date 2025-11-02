import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/waitlist_models.dart';
import 'package:atv_events/features/shared/services/waitlist_service.dart' hide debugPrint;
import 'package:intl/intl.dart';

/// Bottom sheet for joining a product waitlist
/// Shows product preview, waitlist info, and notification preferences
class WaitlistJoinSheet extends StatefulWidget {
  final String productId;
  final String productName;
  final String? productImageUrl;
  final String sellerId;
  final String sellerName;
  final double? price;
  final VoidCallback? onJoined;

  const WaitlistJoinSheet({
    super.key,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.sellerId,
    required this.sellerName,
    this.price,
    this.onJoined,
  });

  @override
  State<WaitlistJoinSheet> createState() => _WaitlistJoinSheetState();
}

class _WaitlistJoinSheetState extends State<WaitlistJoinSheet> {
  final WaitlistService _waitlistService = WaitlistService();

  int _quantity = 1;
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _isLoading = false;
  int _currentWaitlistCount = 0;

  @override
  void initState() {
    super.initState();
    _loadWaitlistInfo();
  }

  Future<void> _loadWaitlistInfo() async {
    try {
      final count = await _waitlistService.getWaitlistCount(widget.productId);

      if (mounted) {
        setState(() {
          _currentWaitlistCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error loading waitlist info: $e');
    }
  }

  Future<void> _joinWaitlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to join the waitlist'),
          backgroundColor: HiPopColors.errorPlum,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Determine notification preference
      NotificationPreference notificationPref = NotificationPreference.push;
      if (_emailNotifications) {
        notificationPref = NotificationPreference.email;
      }

      final entry = await _waitlistService.joinWaitlist(
        productId: widget.productId,
        productName: widget.productName,
        productImageUrl: widget.productImageUrl,
        sellerId: widget.sellerId,
        sellerName: widget.sellerName,
        quantityRequested: _quantity,
        notificationPreference: notificationPref,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();

        // Show success message with position
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You are #${entry.position} in line for ${widget.productName}',
              style: const TextStyle(color: HiPopColors.darkTextPrimary),
            ),
            backgroundColor: HiPopColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );

        widget.onJoined?.call();
        Navigator.of(context).pop();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();

      if (mounted) {
        String errorMessage = 'Failed to join waitlist';
        if (e.toString().contains('already on waitlist')) {
          errorMessage = 'You are already on the waitlist for this product';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: HiPopColors.errorPlum,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(symbol: '\$');

    return Container(
      decoration: const BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title
              const Text(
                'Join Waitlist',
                style: TextStyle(
                  color: HiPopColors.darkTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Product preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: HiPopColors.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    // Product image
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: widget.productImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                widget.productImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stack) {
                                  return const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag,
                              size: 40,
                              color: Colors.grey,
                            ),
                    ),
                    const SizedBox(width: 16),

                    // Product info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.productName,
                            style: const TextStyle(
                              color: HiPopColors.darkTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (widget.price != null)
                            Text(
                              currencyFormatter.format(widget.price),
                              style: const TextStyle(
                                color: HiPopColors.warningAmber,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Current waitlist info
              if (_currentWaitlistCount > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HiPopColors.warningAmber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 20,
                        color: HiPopColors.warningAmber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_currentWaitlistCount ${_currentWaitlistCount == 1 ? "person" : "people"} waiting',
                        style: const TextStyle(
                          color: HiPopColors.warningAmber,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Quantity selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: HiPopColors.darkBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: HiPopColors.darkBorder.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _quantity--;
                                  });
                                }
                              : null,
                          icon: Icon(
                            Icons.remove,
                            color: _quantity > 1
                                ? HiPopColors.darkTextPrimary
                                : HiPopColors.darkTextDisabled,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                        Container(
                          width: 48,
                          alignment: Alignment.center,
                          child: Text(
                            _quantity.toString(),
                            style: const TextStyle(
                              color: HiPopColors.darkTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _quantity < 10
                              ? () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _quantity++;
                                  });
                                }
                              : null,
                          icon: Icon(
                            Icons.add,
                            color: _quantity < 10
                                ? HiPopColors.darkTextPrimary
                                : HiPopColors.darkTextDisabled,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notification preferences
              const Text(
                'Notification Preferences',
                style: TextStyle(
                  color: HiPopColors.darkTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // Push notifications toggle
              Container(
                decoration: BoxDecoration(
                  color: HiPopColors.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.2),
                  ),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Push Notifications',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Get instant alerts when available',
                    style: TextStyle(
                      color: HiPopColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: _pushNotifications,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _pushNotifications = value;
                      if (value) {
                        _emailNotifications = false;
                      }
                    });
                  },
                  activeColor: HiPopColors.primaryDeepSage,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Email notifications toggle
              Container(
                decoration: BoxDecoration(
                  color: HiPopColors.darkBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.2),
                  ),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Email Notifications',
                    style: TextStyle(
                      color: HiPopColors.darkTextPrimary,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    'Receive updates via email',
                    style: TextStyle(
                      color: HiPopColors.darkTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                  value: _emailNotifications,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _emailNotifications = value;
                      if (value) {
                        _pushNotifications = false;
                      }
                    });
                  },
                  activeColor: HiPopColors.primaryDeepSage,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Terms text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.infoBlueGray.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 20,
                      color: HiPopColors.infoBlueGray,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'You\'ll have 24 hours to claim your spot when the product becomes available',
                        style: TextStyle(
                          color: HiPopColors.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _joinWaitlist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.warningAmber,
                    disabledBackgroundColor: HiPopColors.warningAmber.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              HiPopColors.darkBackground,
                            ),
                          ),
                        )
                      : const Text(
                          'Join Waitlist',
                          style: TextStyle(
                            color: HiPopColors.darkBackground,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}