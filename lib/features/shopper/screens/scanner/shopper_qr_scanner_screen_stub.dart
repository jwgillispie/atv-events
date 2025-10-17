import 'package:flutter/material.dart';

class ShopperQRScannerScreen extends StatelessWidget {
  const ShopperQRScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner'),
      ),
      body: const Center(
        child: Text('QR scanning is not available on this platform'),
      ),
    );
  }
}
