import 'package:flutter/material.dart';

/// Stub implementation for platforms that don't support QR scanning (Web)
class TicketScannerScreen extends StatelessWidget {
  final String eventId;
  final String eventTitle;

  const TicketScannerScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan Tickets - $eventTitle'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 24),
            Text(
              'QR Code Scanning',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'QR code scanning is not available on web.\nPlease use the mobile app to scan tickets.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}