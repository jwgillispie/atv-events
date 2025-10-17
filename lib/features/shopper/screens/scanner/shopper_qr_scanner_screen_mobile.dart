import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import 'dart:async';
import 'dart:io';

class ShopperQRScannerScreen extends StatefulWidget {
  const ShopperQRScannerScreen({super.key});

  @override
  State<ShopperQRScannerScreen> createState() => _ShopperQRScannerScreenState();
}

class _ShopperQRScannerScreenState extends State<ShopperQRScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  bool _isProcessing = false;
  String? _lastScannedCode;
  Timer? _resetTimer;
  bool _torchOn = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

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
    print('🟣 [QR SCANNER] ========== QR CODE SCANNED ==========');
    print('🟣 [QR SCANNER] Raw QR code: "$code"');

    // Prevent processing the same code multiple times
    if (_isProcessing || code == _lastScannedCode) {
      print('🟣 [QR SCANNER] Skipping - already processing or duplicate');
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Parse QR code format: hipop://review/vendor/{vendorId} OR hipop://review/market/{marketId}
    String? reviewRoute;

    if (code.startsWith('hipop://review/vendor/')) {
      final vendorId = code.replaceFirst('hipop://review/vendor/', '');
      print('🟣 [QR SCANNER] Detected VENDOR review QR');
      print('🟣 [QR SCANNER] Extracted vendorId: "$vendorId"');

      if (vendorId.isEmpty) {
        print('🔴 [QR SCANNER] ERROR: Vendor ID is empty!');
        _showError('Invalid QR Code', 'Vendor ID is missing');
        return;
      }
      reviewRoute = '/review/vendor/$vendorId';
      print('🟣 [QR SCANNER] Navigating to route: $reviewRoute');
    } else if (code.startsWith('hipop://review/market/')) {
      final marketId = code.replaceFirst('hipop://review/market/', '');
      print('🟣 [QR SCANNER] Detected MARKET review QR');
      print('🟣 [QR SCANNER] Extracted marketId: "$marketId"');

      if (marketId.isEmpty) {
        print('🔴 [QR SCANNER] ERROR: Market ID is empty!');
        _showError('Invalid QR Code', 'Market ID is missing');
        return;
      }
      reviewRoute = '/review/market/$marketId';
      print('🟣 [QR SCANNER] Navigating to route: $reviewRoute');
    } else {
      print('🔴 [QR SCANNER] ERROR: Invalid QR code format!');
      print('🔴 [QR SCANNER] Expected format: hipop://review/vendor/{id} or hipop://review/market/{id}');
      _showError('Invalid QR Code', 'This is not a valid HiPop review code');
      return;
    }

    // Pause camera to prevent re-scanning
    await controller?.pauseCamera();

    // Navigate to review flow
    if (mounted) {
      context.push(reviewRoute).then((_) {
        // Resume camera when coming back
        if (mounted) {
          controller?.resumeCamera();
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
        }
      });
    }
  }

  void _showError(String title, String message) {
    HapticFeedback.mediumImpact();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: HiPopColors.errorPlum,
        duration: const Duration(seconds: 3),
      ),
    );

    // Reset after showing error
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastScannedCode = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // QR Scanner
          QRView(
            key: qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: HiPopColors.shopperAccent,
              borderRadius: 10,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 300,
            ),
          ),

          // Top bar with title and close button
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan Vendor QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleTorch,
                    icon: Icon(
                      _torchOn ? Icons.flash_on : Icons.flash_off,
                      color: _torchOn ? HiPopColors.shopperAccent : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: HiPopColors.shopperAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Point camera at vendor\'s review QR code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
