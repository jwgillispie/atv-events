import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/ticket_purchase.dart';
import '../services/ticket_purchase_service.dart';
import '../../shared/widgets/common/loading_widget.dart';
import '../../shared/widgets/common/error_widget.dart' as common_error;
import '../../../core/theme/atv_colors.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  Future<void> _refreshTickets() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Force refresh by clearing cache
      await TicketPurchaseService.clearCachedTickets(user.uid);
      // The stream will automatically reload
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Tickets'),
          backgroundColor: HiPopColors.darkSurface,
          foregroundColor: HiPopColors.darkTextPrimary,
        ),
        body: const Center(
          child: Text('Please sign in to view your tickets'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('My Tickets'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _refreshTickets,
        color: HiPopColors.primaryDeepSage,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(
                color: HiPopColors.darkSurface,
                child: TabBar(
                  indicatorColor: HiPopColors.primaryDeepSage,
                  labelColor: HiPopColors.primaryDeepSage,
                  unselectedLabelColor: HiPopColors.darkTextSecondary,
                  tabs: const [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Past'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _UpcomingTicketsTab(userId: user.uid, refreshKey: _refreshKey),
                    _PastTicketsTab(userId: user.uid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingTicketsTab extends StatelessWidget {
  final String userId;
  final GlobalKey<RefreshIndicatorState>? refreshKey;

  const _UpcomingTicketsTab({required this.userId, this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TicketPurchase>>(
      stream: TicketPurchaseService.getUserUpcomingTickets(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (snapshot.hasError) {
          return Center(
            child: common_error.ErrorDisplayWidget(
              title: 'Error',
              message: 'Failed to load tickets',
              onRetry: () {},
            ),
          );
        }

        final tickets = snapshot.data ?? [];

        if (tickets.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.confirmation_number_outlined,
            title: 'No Upcoming Tickets',
            subtitle: 'Your upcoming event tickets will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return _TicketCard(
              ticket: ticket,
              onTap: () => _showTicketDetails(context, ticket),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: HiPopColors.darkTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketDetails(BuildContext context, TicketPurchase ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailSheet(ticket: ticket),
    );
  }
}

class _PastTicketsTab extends StatelessWidget {
  final String userId;

  const _PastTicketsTab({required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TicketPurchase>>(
      stream: TicketPurchaseService.getUserTickets(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: LoadingWidget());
        }

        if (snapshot.hasError) {
          return Center(
            child: common_error.ErrorDisplayWidget(
              title: 'Error',
              message: 'Failed to load tickets',
              onRetry: () {},
            ),
          );
        }

        final allTickets = snapshot.data ?? [];
        final pastTickets = allTickets
            .where((ticket) => ticket.isEventPassed || ticket.isUsed)
            .toList();

        if (pastTickets.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.history,
            title: 'No Past Tickets',
            subtitle: 'Your past event tickets will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pastTickets.length,
          itemBuilder: (context, index) {
            final ticket = pastTickets[index];
            return _TicketCard(
              ticket: ticket,
              isPast: true,
              onTap: () => _showTicketDetails(context, ticket),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: HiPopColors.darkTextPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HiPopColors.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showTicketDetails(BuildContext context, TicketPurchase ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TicketDetailSheet(ticket: ticket),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final TicketPurchase ticket;
  final bool isPast;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    this.isPast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Card(
      elevation: 2,
      color: HiPopColors.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPast ? Colors.grey.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Name & Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket.eventName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: HiPopColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  _buildStatusBadge(),
                ],
              ),
              const SizedBox(height: 8),

              // Ticket Type & Quantity
              Text(
                ticket.purchaseSummary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Event Date & Time
              if (ticket.eventStartDate != null)
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${dateFormat.format(ticket.eventStartDate!)} at ${timeFormat.format(ticket.eventStartDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),

              // Location
              if (ticket.eventLocation != null)
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: HiPopColors.darkTextSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ticket.eventLocation!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HiPopColors.darkTextSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

              // Tap to view QR code hint
              if (!isPast && ticket.isValid)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code,
                        size: 16,
                        color: HiPopColors.primaryDeepSage,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view QR code',
                        style: TextStyle(
                          fontSize: 12,
                          color: HiPopColors.primaryDeepSage,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color backgroundColor;
    Color textColor;
    String text;

    if (ticket.isUsed) {
      backgroundColor = Colors.grey;
      textColor = Colors.white;
      text = 'Used';
    } else if (ticket.isEventPassed) {
      backgroundColor = Colors.grey;
      textColor = Colors.white;
      text = 'Expired';
    } else if (ticket.isValid) {
      backgroundColor = Colors.green;
      textColor = Colors.white;
      text = 'Valid';
    } else {
      backgroundColor = Colors.red;
      textColor = Colors.white;
      text = ticket.statusText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TicketDetailSheet extends StatefulWidget {
  final TicketPurchase ticket;

  const _TicketDetailSheet({required this.ticket});

  @override
  State<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends State<_TicketDetailSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();
  double? _originalBrightness;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _boostBrightness();
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _boostBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness().current;
      await ScreenBrightness().setScreenBrightness(1.0); // Max brightness
    } catch (e) {
      debugPrint('Failed to boost brightness: $e');
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
      }
    } catch (e) {
      debugPrint('Failed to restore brightness: $e');
    }
  }

  Future<void> _shareTicket() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Capture QR code as image
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes != null) {
        // Save to temp file
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/ticket_qr_${widget.ticket.id}.png')
            .create();
        await file.writeAsBytes(imageBytes);

        // Share the image with text
        final text = '''Check out my ticket for ${widget.ticket.eventName}!

Event: ${widget.ticket.eventName}
Ticket: ${widget.ticket.ticketName}
Date: ${widget.ticket.eventStartDate != null ? DateFormat('MMM dd, yyyy').format(widget.ticket.eventStartDate!) : 'TBD'}
Location: ${widget.ticket.eventLocation ?? 'TBD'}

Get your tickets on HiPop Markets!''';

        await Share.shareXFiles(
          [XFile(file.path)],
          text: text,
          subject: 'My ticket for ${widget.ticket.eventName}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveToGallery() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Capture QR code as image
      final Uint8List? imageBytes = await _screenshotController.capture(
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 10),
      );

      if (imageBytes != null) {
        // Save to gallery
        final result = await ImageGallerySaver.saveImage(
          imageBytes,
          name: 'hipop_ticket_${widget.ticket.id}',
          quality: 100,
        );

        if (mounted) {
          final success = result['isSuccess'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Ticket saved to gallery!'
                    : 'Failed to save ticket',
              ),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save ticket: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final timeFormat = DateFormat('h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: HiPopColors.darkSurface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: HiPopColors.darkBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Event Name
              Text(
                widget.ticket.eventName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: HiPopColors.darkTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Ticket Type
              Text(
                widget.ticket.ticketName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: HiPopColors.primaryDeepSage,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              // QR Code (if valid)
              if (widget.ticket.isValid && !widget.ticket.isUsed && !widget.ticket.isEventPassed)
                Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data: widget.ticket.qrCode,
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.ticket.eventName,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          widget.ticket.ticketName,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else if (widget.ticket.isUsed)
                _buildDisabledQRCode(
                  context,
                  'This ticket has been used',
                  Icons.check_circle_outline,
                )
              else if (widget.ticket.isEventPassed)
                _buildDisabledQRCode(
                  context,
                  'This event has passed',
                  Icons.event_busy,
                )
              else
                _buildDisabledQRCode(
                  context,
                  'Ticket not valid',
                  Icons.error_outline,
                ),

              // Action buttons for valid tickets
              if (widget.ticket.isValid && !widget.ticket.isUsed && !widget.ticket.isEventPassed) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Share button
                    _ActionButton(
                      icon: Icons.share,
                      label: 'Share',
                      onTap: _shareTicket,
                      isLoading: _isProcessing,
                    ),
                    // Save to gallery button
                    _ActionButton(
                      icon: Icons.download,
                      label: 'Save',
                      onTap: _saveToGallery,
                      isLoading: _isProcessing,
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Ticket Details
              _buildDetailRow(
                Icons.confirmation_number,
                'Quantity',
                '${widget.ticket.quantity} ticket${widget.ticket.quantity > 1 ? 's' : ''}',
              ),
              const SizedBox(height: 12),

              if (widget.ticket.eventStartDate != null)
                _buildDetailRow(
                  Icons.calendar_today,
                  'Date',
                  dateFormat.format(widget.ticket.eventStartDate!),
                ),
              const SizedBox(height: 12),

              if (widget.ticket.eventStartDate != null)
                _buildDetailRow(
                  Icons.access_time,
                  'Time',
                  timeFormat.format(widget.ticket.eventStartDate!),
                ),
              const SizedBox(height: 12),

              if (widget.ticket.eventLocation != null)
                _buildDetailRow(
                  Icons.location_on,
                  'Location',
                  widget.ticket.eventLocation!,
                ),
              const SizedBox(height: 12),

              _buildDetailRow(
                Icons.receipt,
                'Total Paid',
                widget.ticket.formattedTotalAmount,
              ),
              const SizedBox(height: 12),

              _buildDetailRow(
                Icons.calendar_month,
                'Purchased',
                DateFormat('MMM dd, yyyy').format(widget.ticket.purchasedAt),
              ),

              const SizedBox(height: 24),

              // QR Code ID
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: HiPopColors.darkBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Ticket ID',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      widget.ticket.qrCode,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: HiPopColors.darkTextPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Close',
                    style: TextStyle(
                      color: HiPopColors.primaryDeepSage,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Add safe area padding at bottom
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: HiPopColors.darkTextSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: HiPopColors.darkTextSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: HiPopColors.darkTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledQRCode(BuildContext context, String message, IconData icon) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: HiPopColors.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: HiPopColors.darkBorder,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: HiPopColors.darkTextSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: HiPopColors.darkTextSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Action button widget for ticket actions
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: HiPopColors.primaryDeepSage.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    HiPopColors.primaryDeepSage,
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: HiPopColors.primaryDeepSage,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: HiPopColors.primaryDeepSage,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}