// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:flutter/material.dart';

class VendorFollowButton extends StatelessWidget {
  final String vendorId;
  final String? vendorName; // Optional vendor name for display
  final bool isFollowing;
  final VoidCallback? onPressed;
  final bool isCompact; // Compact display mode

  const VendorFollowButton({
    super.key,
    required this.vendorId,
    this.vendorName,
    this.isFollowing = false,
    this.onPressed,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(isFollowing ? 'Following' : 'Follow'),
    );
  }
}
