import 'package:flutter/material.dart';

/// Widget for displaying a vendor's market-specific items as chips/tags
class VendorItemsWidget extends StatelessWidget {
  final List<String> items;
  final int? maxItems;
  final bool showCount;
  final VendorItemsStyle style;
  final String? emptyStateText;

  const VendorItemsWidget({
    super.key,
    required this.items,
    this.maxItems,
    this.showCount = true,
    this.style = VendorItemsStyle.chips,
    this.emptyStateText,
  });

  /// Compact style for inline display (e.g., in market cards)
  const VendorItemsWidget.compact({
    super.key,
    required this.items,
    this.emptyStateText,
  })  : maxItems = 3,
        showCount = true,
        style = VendorItemsStyle.compact;

  /// Full style for detailed views (e.g., in market detail)
  const VendorItemsWidget.full({
    super.key,
    required this.items,
    this.emptyStateText,
  })  : maxItems = null,
        showCount = false,
        style = VendorItemsStyle.chips;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _buildEmptyState(context);
    }

    final displayItems = maxItems != null && items.length > maxItems!
        ? items.take(maxItems!).toList()
        : items;
    final remainingCount = maxItems != null && items.length > maxItems!
        ? items.length - maxItems!
        : 0;

    switch (style) {
      case VendorItemsStyle.compact:
        return _buildCompactStyle(context, displayItems, remainingCount);
      case VendorItemsStyle.chips:
        return _buildChipsStyle(context, displayItems, remainingCount);
      case VendorItemsStyle.list:
        return _buildListStyle(context, displayItems, remainingCount);
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity( 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity( 0.3)),
      ),
      child: Text(
        emptyStateText ?? 'Items coming soon',
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildCompactStyle(BuildContext context, List<String> displayItems, int remainingCount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            displayItems.join(' • '),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (remainingCount > 0) ...[
          const SizedBox(width: 4),
          Text(
            '+$remainingCount',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChipsStyle(BuildContext context, List<String> displayItems, int remainingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ...displayItems.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity( 0.2)),
              ),
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[800],
                  fontWeight: FontWeight.w500,
                ),
              ),
            )),
            if (remainingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity( 0.3)),
                ),
                child: Text(
                  '+$remainingCount more',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildListStyle(BuildContext context, List<String> displayItems, int remainingCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...displayItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.blue[600],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        )),
        if (remainingCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'and $remainingCount more items...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

enum VendorItemsStyle {
  compact,  // Single line with bullet separators
  chips,    // Wrapped chips/tags
  list,     // Vertical list with bullet points
}