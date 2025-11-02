import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event_ticket.dart';
import '../../../core/theme/hipop_colors.dart';
import 'package:intl/intl.dart';

class TicketConfigurationWidget extends StatefulWidget {
  final List<EventTicket>? initialTickets;
  final Function(bool hasTicketing, List<Map<String, dynamic>> tickets) onTicketsChanged;
  final bool isEditing;

  const TicketConfigurationWidget({
    super.key,
    this.initialTickets,
    required this.onTicketsChanged,
    this.isEditing = false,
  });

  @override
  State<TicketConfigurationWidget> createState() => _TicketConfigurationWidgetState();
}

class _TicketConfigurationWidgetState extends State<TicketConfigurationWidget> {
  bool _hasTicketing = false;
  final List<_TicketTypeConfig> _ticketTypes = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialTickets != null && widget.initialTickets!.isNotEmpty) {
      _hasTicketing = true;
      for (final ticket in widget.initialTickets!) {
        _ticketTypes.add(_TicketTypeConfig.fromEventTicket(ticket));
      }
    } else {
      // Add default ticket type
      _ticketTypes.add(_TicketTypeConfig());
    }
  }

  void _updateParent() {
    final ticketData = _ticketTypes
        .map((config) => config.toMap())
        .toList();
    widget.onTicketsChanged(_hasTicketing, ticketData);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? HiPopColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? HiPopColors.darkBorder : Colors.grey[300]!,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ticketing Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: HiPopColors.primaryDeepSage,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Event Ticketing',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _hasTicketing,
                onChanged: (value) {
                  setState(() {
                    _hasTicketing = value;
                    if (_hasTicketing && _ticketTypes.isEmpty) {
                      _ticketTypes.add(_TicketTypeConfig());
                    }
                    _updateParent();
                  });
                },
                activeColor: HiPopColors.primaryDeepSage,
              ),
            ],
          ),

          if (_hasTicketing) ...[
            const SizedBox(height: 8),
            Text(
              'Set up ticketing to sell tickets for your event. HiPop charges a 6% platform fee on all ticket sales.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDarkMode ? HiPopColors.darkTextSecondary : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),

            // Ticket Types
            Text(
              'Ticket Types',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            ..._ticketTypes.asMap().entries.map((entry) {
              final index = entry.key;
              final config = entry.value;
              return _buildTicketTypeCard(context, index, config);
            }),

            const SizedBox(height: 12),

            // Add Ticket Type Button
            if (_ticketTypes.length < 5) // Max 5 ticket types
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _ticketTypes.add(_TicketTypeConfig());
                    _updateParent();
                  });
                },
                icon: Icon(
                  Icons.add,
                  color: HiPopColors.primaryDeepSage,
                ),
                label: Text(
                  'Add Ticket Type',
                  style: TextStyle(
                    color: HiPopColors.primaryDeepSage,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketTypeCard(BuildContext context, int index, _TicketTypeConfig config) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDarkMode ? HiPopColors.darkBackground : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Delete Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ticket Type ${index + 1}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_ticketTypes.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () {
                      setState(() {
                        _ticketTypes.removeAt(index);
                        _updateParent();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Ticket Name
            TextFormField(
              controller: config.nameController,
              decoration: InputDecoration(
                labelText: 'Ticket Name',
                hintText: 'e.g., General Admission, VIP, Early Bird',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: config.descriptionController,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'What does this ticket include?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLines: 2,
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 12),

            // Price and Quantity Row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: config.priceController,
                    decoration: InputDecoration(
                      labelText: 'Price (\$)',
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    onChanged: (_) => _updateParent(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: config.quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: '100',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (_) => _updateParent(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Max per Purchase
            TextFormField(
              controller: config.maxPerPurchaseController,
              decoration: InputDecoration(
                labelText: 'Max Tickets per Purchase',
                hintText: '10',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (_) => _updateParent(),
            ),
            const SizedBox(height: 12),

            // Advanced Options Toggle
            ExpansionTile(
              title: Text(
                'Advanced Options',
                style: theme.textTheme.bodyMedium,
              ),
              children: [
                const SizedBox(height: 8),
                // Sales Start Date
                ListTile(
                  title: const Text('Sales Start Date'),
                  subtitle: Text(
                    config.salesStartDate != null
                        ? DateFormat('MMM dd, yyyy h:mm a').format(config.salesStartDate!)
                        : 'Immediately',
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      config.salesStartDate != null ? Icons.clear : Icons.calendar_today,
                    ),
                    onPressed: () async {
                      if (config.salesStartDate != null) {
                        setState(() {
                          config.salesStartDate = null;
                          _updateParent();
                        });
                      } else {
                        final date = await _selectDateTime(context, 'Sales Start');
                        if (date != null) {
                          setState(() {
                            config.salesStartDate = date;
                            _updateParent();
                          });
                        }
                      }
                    },
                  ),
                ),
                // Sales End Date
                ListTile(
                  title: const Text('Sales End Date'),
                  subtitle: Text(
                    config.salesEndDate != null
                        ? DateFormat('MMM dd, yyyy h:mm a').format(config.salesEndDate!)
                        : 'Event start time',
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      config.salesEndDate != null ? Icons.clear : Icons.calendar_today,
                    ),
                    onPressed: () async {
                      if (config.salesEndDate != null) {
                        setState(() {
                          config.salesEndDate = null;
                          _updateParent();
                        });
                      } else {
                        final date = await _selectDateTime(context, 'Sales End');
                        if (date != null) {
                          setState(() {
                            config.salesEndDate = date;
                            _updateParent();
                          });
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDateTime(BuildContext context, String title) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        return DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      }
    }

    return null;
  }

  @override
  void dispose() {
    for (final config in _ticketTypes) {
      config.dispose();
    }
    super.dispose();
  }
}

class _TicketTypeConfig {
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController quantityController;
  final TextEditingController maxPerPurchaseController;
  DateTime? salesStartDate;
  DateTime? salesEndDate;

  _TicketTypeConfig({
    String name = '',
    String description = '',
    String price = '',
    String quantity = '',
    String maxPerPurchase = '10',
    this.salesStartDate,
    this.salesEndDate,
  })  : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description),
        priceController = TextEditingController(text: price),
        quantityController = TextEditingController(text: quantity),
        maxPerPurchaseController = TextEditingController(text: maxPerPurchase);

  factory _TicketTypeConfig.fromEventTicket(EventTicket ticket) {
    return _TicketTypeConfig(
      name: ticket.name,
      description: ticket.description,
      price: ticket.price.toStringAsFixed(2),
      quantity: ticket.totalQuantity.toString(),
      maxPerPurchase: ticket.maxPerPurchase.toString(),
      salesStartDate: ticket.salesStartDate,
      salesEndDate: ticket.salesEndDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nameController.text,
      'description': descriptionController.text,
      'price': double.tryParse(priceController.text) ?? 0.0,
      'totalQuantity': int.tryParse(quantityController.text) ?? 0,
      'maxPerPurchase': int.tryParse(maxPerPurchaseController.text) ?? 10,
      'salesStartDate': salesStartDate,
      'salesEndDate': salesEndDate,
    };
  }

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    quantityController.dispose();
    maxPerPurchaseController.dispose();
  }
}