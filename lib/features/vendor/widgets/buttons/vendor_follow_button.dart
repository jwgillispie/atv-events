// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:flutter/material.dart';

class VendorFollowButton extends StatelessWidget {
  final String vendorId;
  final bool isFollowing;
  final VoidCallback? onPressed;

  const VendorFollowButton({
    super.key,
    required this.vendorId,
    this.isFollowing = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(isFollowing ? 'Following' : 'Follow'),
    );
  }
}
