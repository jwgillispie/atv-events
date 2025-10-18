// TODO: Removed for ATV Events demo - Ticket features disabled
// This is a stub to maintain compilation

import 'package:flutter/material.dart';

class EventTicketsSection extends StatelessWidget {
  final String? eventId;
  final String? marketId; // Optional market ID parameter
  final dynamic event; // Flexible event parameter
  final dynamic currentUser; // Flexible user parameter

  const EventTicketsSection({
    super.key,
    this.eventId,
    this.marketId,
    this.event,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink(); // Hidden - ticket features disabled
  }
}
