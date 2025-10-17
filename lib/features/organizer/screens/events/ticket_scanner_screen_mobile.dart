import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'dart:async';
import 'dart:io';

class TicketScannerScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;

  const TicketScannerScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  bool _isProcessing = false;
  String? _lastScannedCode;
  Timer? _resetTimer;
  bool _torchOn = false;

  // Overlay state
  bool _showOverlay = false;
  bool _isSuccess = false;
  String _overlayTitle = '';
  String _overlayMessage = '';
  Map<String, dynamic>? _ticketData;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    }
    controller?.resumeCamera();
  }

  Future<void> _toggleTorch() async {
    setState(() {
      _torchOn = !_torchOn;
    });
    await controller?.toggleFlash();
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });

    controller.scannedDataStream.listen((scanData) {
      if (scanData.code != null) {
        _processQRCode(scanData.code!);
      }
    });
  }

  Future<void> _processQRCode(String code) async {
    // Prevent processing the same code multiple times
    if (_isProcessing || code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Parse QR code format: HIP-{eventId}-{ticketId}-{timestamp}-{random}
    final parts = code.split('-');
    if (parts.length < 3 || parts[0] != 'HIP') {
      _showResultOverlay(
        success: false,
        title: 'Invalid QR Code',
        message: 'This is not a valid HiPop ticket',
      );
      return;
    }

    final qrEventId = parts[1];
    final ticketId = parts[2];

    // Check if ticket is for this event
    if (qrEventId != widget.eventId) {
      _showResultOverlay(
        success: false,
        title: 'Wrong Event',
        message: 'This ticket is for a different event',
      );
      return;
    }

    try {
      // Call Firebase function to validate ticket
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('validateTicket');

      final result = await callable.call({
        'ticketId': ticketId,
        'eventId': widget.eventId,
        'qrCode': code,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        _showResultOverlay(
          success: true,
          title: 'Check-in Successful!',
          message: '${data['attendeeName'] ?? 'Guest'}\n${data['ticketType'] ?? 'General Admission'}',
          ticketData: data,
        );
      } else {
        final errorMessage = data['error'] ?? 'Validation failed';
        String title = 'Invalid Ticket';

        if (errorMessage.contains('already used')) {
          title = 'Already Checked In';
        } else if (errorMessage.contains('not found')) {
          title = 'Ticket Not Found';
        } else if (errorMessage.contains('event has ended')) {
          title = 'Event Ended';
        }

        _showResultOverlay(
          success: false,
          title: title,
          message: errorMessage,
        );
      }
    } catch (e) {
      _showResultOverlay(
        success: false,
        title: 'Connection Error',
        message: 'Please check your internet connection',
      );
    }
  }

  void _showResultOverlay({
    required bool success,
    required String title,
    required String message,
    Map<String, dynamic>? ticketData,
  }) {
    setState(() {
      _showOverlay = true;
      _isSuccess = success;
      _overlayTitle = title;
      _overlayMessage = message;
      _ticketData = ticketData;
    });

    // Haptic feedback
    if (success) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }

    // Auto-hide overlay and reset scanner
    _resetTimer?.cancel();
    _resetTimer = Timer(Duration(seconds: success ? 2 : 3), () {
      if (mounted) {
        setState(() {
          _showOverlay = false;
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      body: Stack(
        children: [
          // QR Scanner View
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: HiPopColors.organizerAccent,
              borderRadius: 20,
              borderLength: 40,
              borderWidth: 8,
              cutOutSize: 280,
              overlayColor: Colors.black.withValues(alpha: 0.5),
            ),
          ),

          // Top Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Header with event name
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: HiPopColors.darkSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: HiPopColors.organizerAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Scanning Tickets',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.eventTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Torch toggle
                        IconButton(
                          onPressed: _toggleTorch,
                          icon: Icon(
                            _torchOn ? Icons.flash_on : Icons.flash_off,
                            color: _torchOn ? HiPopColors.warningAmber : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Result Overlay
          if (_showOverlay)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isSuccess
                        ? HiPopColors.successGreen.withValues(alpha: 0.5)
                        : HiPopColors.errorPlum.withValues(alpha: 0.5),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isSuccess
                          ? HiPopColors.successGreen
                          : HiPopColors.errorPlum).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isSuccess
                              ? [HiPopColors.successGreen, HiPopColors.successGreen.withValues(alpha: 0.7)]
                              : [HiPopColors.errorPlum, HiPopColors.errorPlum.withValues(alpha: 0.7)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSuccess ? Icons.check : Icons.close,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        _overlayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // Message
                      Text(
                        _overlayMessage,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Show additional info for successful scans
                      if (_isSuccess && _ticketData != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              if (_ticketData!['quantity'] != null)
                                Text(
                                  'Quantity: ${_ticketData!['quantity']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              if (_ticketData!['purchaseDate'] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Purchased: ${_ticketData!['purchaseDate']}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

          // Scanning indicator
          if (_isProcessing && !_showOverlay)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: HiPopColors.organizerAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}