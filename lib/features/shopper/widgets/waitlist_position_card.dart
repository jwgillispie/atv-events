import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:atv_events/features/shared/models/waitlist_models.dart';
import 'package:atv_events/features/shared/services/waitlist_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

/// Card showing shopper's position in product waitlist
/// Displays product info, position, status, and actions
class WaitlistPositionCard extends StatefulWidget {
  final WaitlistEntry entry;
  final VoidCallback? onLeaveWaitlist;
  final VoidCallback? onClaim;

  const WaitlistPositionCard({
    super.key,
    required this.entry,
    this.onLeaveWaitlist,
    this.onClaim,
  });

  @override
  State<WaitlistPositionCard> createState() => _WaitlistPositionCardState();
}

class _WaitlistPositionCardState extends State<WaitlistPositionCard> {
  final WaitlistService _waitlistService = WaitlistService();
  bool _isLeaving = false;

  Future<void> _handleLeaveWaitlist() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Leave Waitlist?',
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to leave the waitlist for ${widget.entry.productName}? You\'ll lose your position.',
          style: const TextStyle(
            color: HiPopColors.darkTextSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.errorPlum,
            ),
            child: const Text('Leave Waitlist'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLeaving = true;
    });

    try {
      await _waitlistService.leaveWaitlist(
        productId: widget.entry.productId,
        entryId: widget.entry.id,
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('You have left the waitlist'),
            backgroundColor: HiPopColors.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        widget.onLeaveWaitlist?.call();
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to leave waitlist'),
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
          _isLeaving = false;
        });
      }
    }
  }

  void _handleClaim() {
    // Navigate to checkout/claim flow
    context.push('/checkout/claim/${widget.entry.id}');
    widget.onClaim?.call();
  }

  Color _getStatusColor() {
    switch (widget.entry.status) {
      case WaitlistStatus.waiting:
        return HiPopColors.warningAmber;
      case WaitlistStatus.notified:
        return HiPopColors.successGreen;
      case WaitlistStatus.claimed:
        return HiPopColors.primaryDeepSage;
      case WaitlistStatus.expired:
        return HiPopColors.errorPlum;
      case WaitlistStatus.cancelled:
        return HiPopColors.darkTextDisabled;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.entry.status) {
      case WaitlistStatus.waiting:
        return Icons.access_time;
      case WaitlistStatus.notified:
        return Icons.notifications_active;
      case WaitlistStatus.claimed:
        return Icons.check_circle;
      case WaitlistStatus.expired:
        return Icons.timer_off;
      case WaitlistStatus.cancelled:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, y');
    final statusColor = _getStatusColor();
    final statusIcon = _getStatusIcon();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.entry.isNotified
              ? HiPopColors.successGreen.withValues(alpha: 0.3)
              : HiPopColors.darkBorder.withValues(alpha: 0.2),
          width: widget.entry.isNotified ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Product image
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: widget.entry.productImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.entry.productImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return const Icon(
                                Icons.image_not_supported,
                                size: 32,
                                color: Colors.grey,
                              );
                            },
                          ),
                        )
                      : const Icon(
                          Icons.shopping_bag,
                          size: 32,
                          color: Colors.grey,
                        ),
                ),
                const SizedBox(width: 16),

                // Product details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product name
                      Text(
                        widget.entry.productName,
                        style: const TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Position in line
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: HiPopColors.warningAmber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Position #${widget.entry.position}',
                              style: const TextStyle(
                                color: HiPopColors.warningAmber,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 12,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.entry.statusDisplayText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Market info
                      Row(
                        children: [
                          Icon(
                            Icons.store_mall_directory_outlined,
                            size: 14,
                            color: HiPopColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.entry.marketName,
                              style: const TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Popup date
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: HiPopColors.darkTextSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateFormatter.format(widget.entry.popupDate),
                            style: const TextStyle(
                              color: HiPopColors.darkTextSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      // Quantity if more than 1
                      if (widget.entry.quantityRequested > 1) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 14,
                              color: HiPopColors.darkTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Quantity: ${widget.entry.quantityRequested}',
                              style: const TextStyle(
                                color: HiPopColors.darkTextSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action section
          if (widget.entry.isWaiting || widget.entry.isNotified)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.entry.isNotified
                    ? HiPopColors.successGreen.withValues(alpha: 0.1)
                    : HiPopColors.darkBackground,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: widget.entry.isNotified
                  ? Column(
                      children: [
                        // Expiration warning if applicable
                        if (widget.entry.claimExpiresAt != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: HiPopColors.warningAmber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timer,
                                  size: 16,
                                  color: HiPopColors.warningAmber,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Claim by ${dateFormatter.format(widget.entry.claimExpiresAt!)}',
                                    style: const TextStyle(
                                      color: HiPopColors.warningAmber,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Claim button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleClaim,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HiPopColors.successGreen,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Claim Now',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: _isLeaving ? null : _handleLeaveWaitlist,
                        icon: _isLeaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    HiPopColors.errorPlum,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.exit_to_app,
                                size: 18,
                              ),
                        label: Text(
                          _isLeaving ? 'Leaving...' : 'Leave Waitlist',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: HiPopColors.errorPlum,
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}