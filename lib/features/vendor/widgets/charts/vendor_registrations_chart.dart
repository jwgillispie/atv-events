// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:flutter/material.dart';

class VendorRegistrationsChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String? marketId; // Optional market ID for filtering
  final int? monthsBack; // Add monthsBack parameter for compatibility

  const VendorRegistrationsChart({
    super.key,
    required this.data,
    this.marketId,
    this.monthsBack,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Vendor charts disabled for ATV Events demo'),
    );
  }
}
