import 'package:flutter/material.dart';
import '../../models/vendor_application.dart';
import 'dart:async';

/// Reusable card widget displaying a vendor application with status badge
/// Used in both vendor application list and organizer review screens
class ApplicationStatusCard extends StatefulWidget {
  final VendorApplication application;
  final VoidCallback? onPayPressed;
  final VoidCallback? onApprovePressed;
  final VoidCallback? onDenyPressed;
  final VoidCallback? onTap;
  final bool showVendorInfo;

  const ApplicationStatusCard({
    super.key,
    required this.application,
    this.onPayPressed,
    this.onApprovePressed,
    this.onDenyPressed,
    this.onTap,
    this.showVendorInfo = false,
  });

  @override
  State<ApplicationStatusCard> createState() => _ApplicationStatusCardState();
}

class _ApplicationStatusCardState extends State<ApplicationStatusCard> {
  Timer? _countdownTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (!widget.application.isApproved) return;

    _remainingTime = widget.application.timeRemainingToPay;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final remaining = widget.application.timeRemainingToPay;
      if (remaining == null || remaining.inSeconds <= 0) {
        timer.cancel();
        setState(() => _remainingTime = Duration.zero);
      } else {
        setState(() => _remainingTime = remaining);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with market/vendor name and status badge
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.showVendorInfo
                              ? widget.application.vendorName
                              : widget.application.marketName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.showVendorInfo && widget.application.vendorPhotoUrl != null)
                          const SizedBox(height: 4),
                        Text(
                          'Applied ${_formatDate(widget.application.appliedAt)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),

              const SizedBox(height: 12),

              // Description preview
              Text(
                widget.application.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700]),
              ),

              const SizedBox(height: 12),

              // Fees row
              Row(
                children: [
                  if (widget.application.applicationFee > 0) ...[
                    _buildFeeChip('App Fee', widget.application.applicationFee),
                    const SizedBox(width: 8),
                  ],
                  _buildFeeChip('Booth Fee', widget.application.boothFee),
                  const SizedBox(width: 8),
                  _buildFeeChip('Total', widget.application.totalFee, isPrimary: true),
                ],
              ),

              // Countdown timer for approved applications
              if (widget.application.isApproved && _remainingTime != null) ...[
                const SizedBox(height: 12),
                _buildCountdownTimer(),
              ],

              // Denial note
              if (widget.application.isDenied && widget.application.denialNote != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.application.denialNote!,
                          style: TextStyle(color: Colors.red[700], fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action buttons
              if (widget.onPayPressed != null ||
                  widget.onApprovePressed != null ||
                  widget.onDenyPressed != null) ...[
                const SizedBox(height: 16),
                _buildActionButtons(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final status = widget.application.status;
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case ApplicationStatus.pending:
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'Pending';
        break;
      case ApplicationStatus.approved:
        color = Colors.blue;
        icon = Icons.check_circle_outline;
        label = 'Approved';
        break;
      case ApplicationStatus.confirmed:
        color = Colors.green;
        icon = Icons.verified;
        label = 'Confirmed';
        break;
      case ApplicationStatus.denied:
        color = Colors.red;
        icon = Icons.cancel;
        label = 'Denied';
        break;
      case ApplicationStatus.expired:
        color = Colors.grey;
        icon = Icons.access_time;
        label = 'Expired';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeChip(String label, double amount, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: \$${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
          color: isPrimary ? Colors.blue[700] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildCountdownTimer() {
    if (_remainingTime == null) return const SizedBox.shrink();

    final isExpiringSoon = _remainingTime!.inHours < 2;
    final color = isExpiringSoon ? Colors.red : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Time remaining: ${_formatDuration(_remainingTime!)}',
                  style: TextStyle(color: color, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Pay button (for vendors)
        if (widget.onPayPressed != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onPayPressed,
              icon: const Icon(Icons.payment, size: 18),
              label: const Text('Pay Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),

        // Approve button (for organizers)
        if (widget.onApprovePressed != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: widget.onApprovePressed,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),

        if (widget.onApprovePressed != null && widget.onDenyPressed != null)
          const SizedBox(width: 8),

        // Deny button (for organizers)
        if (widget.onDenyPressed != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onDenyPressed,
              icon: const Icon(Icons.cancel, size: 18),
              label: const Text('Deny'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds <= 0) {
      return 'Expired';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hours, $minutes min';
    }
    return '$minutes minutes';
  }
}
