import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/waitlist_models.dart';
import 'package:atv_events/features/shared/services/waitlist_service.dart' hide debugPrint;
import 'package:atv_events/features/shared/widgets/waitlist/waitlist_join_sheet.dart';

/// Waitlist button widget that shows join status and waitlist count
/// Uses warning amber color scheme and shows disabled state if user already joined
class WaitlistButton extends StatefulWidget {
  final String productId;
  final String productName;
  final String? productImageUrl;
  final String vendorId;
  final String vendorName;
  final String popupId;
  final String marketId;
  final String marketName;
  final DateTime popupDate;
  final double? price;
  final VoidCallback? onJoined;
  final bool showCount;
  final bool isCompact;

  const WaitlistButton({
    super.key,
    required this.productId,
    required this.productName,
    this.productImageUrl,
    required this.vendorId,
    required this.vendorName,
    required this.popupId,
    required this.marketId,
    required this.marketName,
    required this.popupDate,
    this.price,
    this.onJoined,
    this.showCount = true,
    this.isCompact = false,
  });

  @override
  State<WaitlistButton> createState() => _WaitlistButtonState();
}

class _WaitlistButtonState extends State<WaitlistButton> {
  final WaitlistService _waitlistService = WaitlistService();
  bool _isOnWaitlist = false;
  int _waitlistCount = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkWaitlistStatus();
  }

  Future<void> _checkWaitlistStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user is on waitlist
      final userEntry = await _waitlistService.getUserWaitlistEntry(
        widget.productId,
      );

      // Get waitlist count
      final count = await _waitlistService.getWaitlistCount(
        widget.productId,
      );

      if (mounted) {
        setState(() {
          _isOnWaitlist = userEntry != null &&
                         (userEntry.status == WaitlistStatus.waiting ||
                          userEntry.status == WaitlistStatus.notified);
          _waitlistCount = count;
        });
      }
    } catch (e) {
      debugPrint('Error checking waitlist status: $e');
    }
  }

  void _handleTap() {
    if (_isOnWaitlist) {
      // Show message that user is already on waitlist
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You are already on the waitlist for this product',
            style: TextStyle(color: HiPopColors.darkTextPrimary),
          ),
          backgroundColor: HiPopColors.warningAmber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    HapticFeedback.selectionClick();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WaitlistJoinSheet(
        productId: widget.productId,
        productName: widget.productName,
        productImageUrl: widget.productImageUrl,
        vendorId: widget.vendorId,
        vendorName: widget.vendorName,
        popupId: widget.popupId,
        marketId: widget.marketId,
        marketName: widget.marketName,
        popupDate: widget.popupDate,
        price: widget.price,
        onJoined: () {
          _checkWaitlistStatus();
          widget.onJoined?.call();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactButton();
    }
    return _buildFullButton();
  }

  Widget _buildFullButton() {
    final isDisabled = _isOnWaitlist;
    final buttonColor = isDisabled
        ? HiPopColors.warningAmber.withValues(alpha: 0.3)
        : HiPopColors.warningAmber;
    final textColor = isDisabled
        ? HiPopColors.darkTextDisabled
        : HiPopColors.darkBackground;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : _handleTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: HiPopColors.warningAmberDark.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isOnWaitlist ? Icons.check_circle : Icons.access_time,
                size: 20,
                color: textColor,
              ),
              const SizedBox(width: 8),
              Text(
                _isOnWaitlist ? 'On Waitlist' : 'Join Waitlist',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.showCount && _waitlistCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkBackground.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _waitlistCount.toString(),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactButton() {
    final isDisabled = _isOnWaitlist;
    final buttonColor = isDisabled
        ? HiPopColors.warningAmber.withValues(alpha: 0.3)
        : HiPopColors.warningAmber;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : _handleTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isOnWaitlist ? Icons.check : Icons.access_time,
                size: 16,
                color: HiPopColors.darkBackground,
              ),
              if (_waitlistCount > 0) ...[
                const SizedBox(width: 4),
                Text(
                  _waitlistCount.toString(),
                  style: const TextStyle(
                    color: HiPopColors.darkBackground,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}