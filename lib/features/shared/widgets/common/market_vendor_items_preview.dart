import 'package:flutter/material.dart';
import '../../../vendor/services/markets/vendor_market_items_service.dart';
import 'vendor_items_widget.dart';

/// Widget that shows a preview of vendor items available at a market
class MarketVendorItemsPreview extends StatelessWidget {
  final String marketId;
  final int maxVendors;
  final int maxItemsPerVendor;

  const MarketVendorItemsPreview({
    super.key,
    required this.marketId,
    this.maxVendors = 3,
    this.maxItemsPerVendor = 2,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, List<String>>>(
      stream: VendorMarketItemsService.getMarketVendorItemsStream(marketId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(context);
        }

        if (snapshot.hasError) {
          return _buildErrorState(context, snapshot.error.toString());
        }

        final vendorItemsMap = snapshot.data ?? <String, List<String>>{};
        
        if (vendorItemsMap.isEmpty) {
          return _buildEmptyState(context);
        }

        return _buildItemsPreview(context, vendorItemsMap);
      },
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Loading vendor items...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity( 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withOpacity( 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront,
            size: 12,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 6),
          Text(
            'Vendor items coming soon',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity( 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity( 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 12,
            color: Colors.red[500],
          ),
          const SizedBox(width: 6),
          Text(
            'Error loading vendor items',
            style: TextStyle(
              fontSize: 11,
              color: Colors.red[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsPreview(BuildContext context, Map<String, List<String>> vendorItemsMap) {
    // Get all unique items from all vendors, prioritizing the most common ones
    final Map<String, int> itemCounts = {};
    
    for (final vendorItems in vendorItemsMap.values) {
      for (final item in vendorItems) {
        itemCounts[item] = (itemCounts[item] ?? 0) + 1;
      }
    }

    // Sort items by frequency (most common first)
    final sortedItems = itemCounts.entries
        .map((e) => e.key)
        .take(6)
        .toList();

    if (sortedItems.isEmpty) {
      return _buildEmptyState(context);
    }

    final vendorCount = vendorItemsMap.length;
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity( 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity( 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_basket,
                size: 12,
                color: Colors.green[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Available from $vendorCount vendor${vendorCount == 1 ? '' : 's'}:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          VendorItemsWidget.compact(
            items: sortedItems,
            emptyStateText: 'Items being updated...',
          ),
        ],
      ),
    );
  }
}