import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class OrganizerMarketQRDisplayScreen extends StatefulWidget {
  final String marketId;

  const OrganizerMarketQRDisplayScreen({
    super.key,
    required this.marketId,
  });

  @override
  State<OrganizerMarketQRDisplayScreen> createState() =>
      _OrganizerMarketQRDisplayScreenState();
}

class _OrganizerMarketQRDisplayScreenState
    extends State<OrganizerMarketQRDisplayScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  late String _qrData;

  @override
  void initState() {
    super.initState();
    _initializeQRData();
  }

  void _initializeQRData() {
    // Create the review URL for this market
    // Using a simple path format that GoRouter can handle
    // This will open in the app if installed, or browser if not
    _qrData = 'hipop://review/market/${widget.marketId}';

    // Alternative for web compatibility:
    // _qrData = 'https://hipop.app/#/review/market/${widget.marketId}';

    // Market name could be fetched from market data if needed
  }

  Future<void> _shareQRCode() async {
    try {
      // Capture the QR code widget as an image
      final Uint8List? image = await _screenshotController.capture();
      if (image == null) return;

      // Save the image to a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/market_qr_code.png').create();
      await file.writeAsBytes(image);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Scan this QR code to leave a review for our market!',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share QR code: ${e.toString()}'),
          backgroundColor: HiPopColors.errorPlum,
        ),
      );
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _qrData));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Review link copied to clipboard!'),
        backgroundColor: HiPopColors.successGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Market Review QR Code'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareQRCode,
            tooltip: 'Share QR Code',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Instructions Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HiPopColors.organizerAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: HiPopColors.organizerAccent,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your Market Review QR Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shoppers with the HiPop app can scan this code to leave a review for this market',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // QR Code Container
            Screenshot(
              controller: _screenshotController,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // QR Code
                    QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 250,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      // Add a logo in the center if desired
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(40, 40),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Label
                    const Text(
                      'Scan to Review Market',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Share your experience',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Column(
              children: [
                // Share Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _shareQRCode,
                    icon: const Icon(Icons.share),
                    label: const Text('Share QR Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HiPopColors.organizerAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Copy Link Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Copy Review Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: HiPopColors.organizerAccent,
                      side: BorderSide(color: HiPopColors.organizerAccent),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // How it Works Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How it Works',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: HiPopColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStep(
                    '1',
                    'Display this QR code at your market',
                    'Display at your market entrance, information booth, or checkout areas',
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '2',
                    'Shoppers scan with HiPop app',
                    'They can quickly leave feedback about their market experience',
                  ),
                  const SizedBox(height: 12),
                  _buildStep(
                    '3',
                    'Build your market reputation',
                    'Reviews help attract more shoppers and vendors to your market',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Tips Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: HiPopColors.organizerAccent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: HiPopColors.organizerAccent.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: HiPopColors.organizerAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Pro Tips',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip('Print and laminate for a permanent display'),
                  const SizedBox(height: 8),
                  _buildTip('Place near exits to catch shoppers after their visit'),
                  const SizedBox(height: 8),
                  _buildTip('Encourage vendors to remind shoppers to leave reviews'),
                  const SizedBox(height: 8),
                  _buildTip('Share on social media to collect reviews between markets'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: HiPopColors.organizerAccent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: HiPopColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: HiPopColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(
            color: HiPopColors.organizerAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tip,
            style: TextStyle(
              fontSize: 13,
              color: HiPopColors.darkTextSecondary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}