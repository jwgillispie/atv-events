// TODO: Removed for ATV Events demo - Vendor features disabled
// This is a stub to maintain compilation

import 'package:flutter/material.dart';
import '../models/vendor_categories.dart';

class CategorySelectionDialog extends StatelessWidget {
  final List<String> selectedCategories;
  final Function(List<String>) onCategoriesSelected;

  const CategorySelectionDialog({
    super.key,
    required this.selectedCategories,
    required this.onCategoriesSelected,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> selectedCategories,
  }) async {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => CategorySelectionDialog(
        selectedCategories: selectedCategories,
        onCategoriesSelected: (categories) {
          Navigator.of(context).pop(categories);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Categories'),
      content: const Text('Vendor features are disabled for ATV Events demo'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop([]),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
