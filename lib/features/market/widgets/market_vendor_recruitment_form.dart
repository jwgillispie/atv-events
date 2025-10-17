import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market.dart';
import '../../premium/services/subscription_service.dart';
import 'category_targeting_section.dart';

/// Enhanced Market Form Section for Vendor Recruitment
/// Provides a clean, conversion-optimized interface for market organizers
/// to configure vendor recruitment settings
class MarketVendorRecruitmentForm extends StatefulWidget {
  final Market? market;
  final bool isLookingForVendors;
  final Function(Map<String, dynamic>) onRecruitmentDataChanged;
  
  const MarketVendorRecruitmentForm({
    super.key,
    this.market,
    required this.isLookingForVendors,
    required this.onRecruitmentDataChanged,
  });
  
  @override
  State<MarketVendorRecruitmentForm> createState() => _MarketVendorRecruitmentFormState();
}

class _MarketVendorRecruitmentFormState extends State<MarketVendorRecruitmentForm>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  // Form controllers
  final _applicationUrlController = TextEditingController();
  final _applicationFeeController = TextEditingController();
  final _dailyBoothFeeController = TextEditingController();
  final _vendorSpotsController = TextEditingController();
  final _vendorRequirementsController = TextEditingController();
  
  // Form state
  bool _isLookingForVendors = false;
  DateTime? _applicationDeadline;
  List<String> _targetCategories = [];

  // Validation
  String? _urlError;
  String? _spotsError;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _initializeFormData();
  }

  void _initializeFormData() {
    final market = widget.market;
    _isLookingForVendors = widget.isLookingForVendors;

    if (market != null) {
      _applicationUrlController.text = market.applicationUrl ?? '';
      _applicationFeeController.text = market.applicationFee?.toString() ?? '';
      _dailyBoothFeeController.text = market.dailyBoothFee?.toString() ?? '';
      _vendorSpotsController.text = market.vendorSpotsTotal?.toString() ?? '';
      _vendorRequirementsController.text = market.vendorRequirements ?? '';
      _applicationDeadline = market.applicationDeadline;
      _targetCategories = market.targetCategories ?? [];
    }

    if (_isLookingForVendors) {
      _animationController.forward();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _applicationUrlController.dispose();
    _applicationFeeController.dispose();
    _dailyBoothFeeController.dispose();
    _vendorSpotsController.dispose();
    _vendorRequirementsController.dispose();
    super.dispose();
  }

  void _toggleRecruitment(bool value) {
    setState(() {
      _isLookingForVendors = value;
      if (value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    _notifyDataChanged();
  }

  void _notifyDataChanged() {
    final data = {
      'isLookingForVendors': _isLookingForVendors,
      'applicationUrl': _applicationUrlController.text.trim(),
      'applicationFee': double.tryParse(_applicationFeeController.text),
      'dailyBoothFee': double.tryParse(_dailyBoothFeeController.text),
      'vendorSpotsTotal': int.tryParse(_vendorSpotsController.text),
      'vendorSpotsAvailable': int.tryParse(_vendorSpotsController.text), // Initially same as total
      'applicationDeadline': _applicationDeadline,
      'vendorRequirements': _vendorRequirementsController.text.trim(),
      'targetCategories': _targetCategories,
    };
    widget.onRecruitmentDataChanged(data);
  }

  void _onCategoriesChanged(List<String> categories) {
    setState(() {
      _targetCategories = categories;
    });
    _notifyDataChanged();
  }
  
  bool _validateUrl(String url) {
    if (url.isEmpty) return true; // Optional field
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
  
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 1));
    final lastDate = now.add(const Duration(days: 365));
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _applicationDeadline ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: HiPopColors.primaryDeepSage,
              onPrimary: HiPopColors.darkTextPrimary,
              surface: HiPopColors.darkSurface,
              onSurface: HiPopColors.darkTextPrimary,
              surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
              onSurfaceVariant: HiPopColors.darkTextSecondary,
              secondary: HiPopColors.accentMauve,
              onSecondary: HiPopColors.darkTextPrimary,
              error: HiPopColors.errorPlum,
              onError: HiPopColors.darkTextPrimary,
              outline: HiPopColors.darkBorder,
              shadow: HiPopColors.darkShadow,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: HiPopColors.darkSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: HiPopColors.darkSurface,
              surfaceTintColor: Colors.transparent,
              headerBackgroundColor: HiPopColors.darkSurfaceVariant,
              headerForegroundColor: HiPopColors.darkTextPrimary,
              weekdayStyle: TextStyle(color: HiPopColors.darkTextSecondary),
              dayStyle: TextStyle(color: HiPopColors.darkTextPrimary),
              yearStyle: TextStyle(color: HiPopColors.darkTextPrimary),
              todayBackgroundColor: WidgetStateProperty.all(HiPopColors.darkSurfaceElevated),
              todayForegroundColor: WidgetStateProperty.all(HiPopColors.primaryDeepSage),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return HiPopColors.primaryDeepSage;
                }
                return null;
              }),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return HiPopColors.darkTextPrimary;
                }
                if (states.contains(WidgetState.disabled)) {
                  return HiPopColors.darkTextDisabled;
                }
                return HiPopColors.darkTextPrimary;
              }),
              yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return HiPopColors.primaryDeepSage;
                }
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return HiPopColors.darkTextPrimary;
                }
                if (states.contains(WidgetState.disabled)) {
                  return HiPopColors.darkTextDisabled;
                }
                return HiPopColors.darkTextPrimary;
              }),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: HiPopColors.primaryDeepSage,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: HiPopColors.darkTextSecondary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _applicationDeadline = picked;
      });
      _notifyDataChanged();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Section with Enhanced Design
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isLookingForVendors 
                  ? HiPopColors.accentMauve 
                  : HiPopColors.darkBorder,
              width: _isLookingForVendors ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Recruit vendors?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isLookingForVendors,
                    onChanged: _toggleRecruitment,
                    activeColor: HiPopColors.primaryDeepSage,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Description Text
              Text(
                'Enable vendor recruitment to appear in vendor discovery feeds and receive applications',
                style: TextStyle(
                  fontSize: 13,
                  color: HiPopColors.darkTextSecondary,
                  height: 1.4,
                ),
              ),
              
              // Animated Info Banner
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HiPopColors.darkBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: HiPopColors.infoBlueGray,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your market will appear in vendor discovery feeds when enabled',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.darkTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Category Targeting Section (animated with toggle)
        CategoryTargetingSection(
          selectedCategories: _targetCategories,
          onCategoriesChanged: _onCategoriesChanged,
          isExpanded: _isLookingForVendors,
        ),

        // Animated Form Fields
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Application URL Field
                _buildFormField(
                  label: 'Application URL (Optional)',
                  hint: 'Leave blank to use HiPop\'s built-in application form',
                  controller: _applicationUrlController,
                  icon: Icons.link,
                  isRequired: false,
                  errorText: _urlError,
                  helperText: 'Leave blank to use in-app applications, or provide an external URL',
                  onChanged: (value) {
                    setState(() {
                      _urlError = _validateUrl(value)
                          ? null
                          : 'Please enter a valid URL';
                    });
                    _notifyDataChanged();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Vendor Spots Field
                _buildFormField(
                  label: 'Number of Vendor Spots',
                  hint: 'Total spots available',
                  controller: _vendorSpotsController,
                  icon: Icons.groups,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: _spotsError,
                  onChanged: (value) {
                    setState(() {
                      final spots = int.tryParse(value);
                      _spotsError = (spots == null || spots <= 0)
                          ? 'Please enter a valid number'
                          : null;
                    });
                    _notifyDataChanged();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Fee Fields Row
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        label: 'Application Fee',
                        hint: '\$0.00',
                        controller: _applicationFeeController,
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _notifyDataChanged(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFormField(
                        label: 'Daily Booth Fee',
                        hint: '\$0.00',
                        controller: _dailyBoothFeeController,
                        icon: Icons.payments,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _notifyDataChanged(),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Application Deadline
                _buildDateField(),
                
                const SizedBox(height: 16),
                
                // Vendor Requirements
                _buildFormField(
                  label: 'Vendor Requirements',
                  hint: 'List any specific requirements for vendors...',
                  controller: _vendorRequirementsController,
                  icon: Icons.checklist,
                  maxLines: 3,
                  onChanged: (_) => _notifyDataChanged(),
                ),
                
                // Visual Feedback Section
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HiPopColors.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 20,
                            color: HiPopColors.successGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Visibility Benefits',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...[
                        'Featured in vendor discovery searches',
                        'Priority placement for urgent deadlines',
                        'Direct vendor applications through the platform',
                        'Automatic spot availability tracking',
                      ].map((benefit) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: HiPopColors.successGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    String? helperText,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: HiPopColors.darkTextTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: HiPopColors.errorPlum,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: HiPopColors.darkTextTertiary,
              fontSize: 14,
            ),
            errorText: errorText,
            errorStyle: TextStyle(
              color: HiPopColors.errorPlum,
              fontSize: 12,
            ),
            helperText: helperText,
            helperStyle: TextStyle(
              color: HiPopColors.darkTextTertiary,
              fontSize: 12,
            ),
            filled: true,
            fillColor: HiPopColors.darkSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: HiPopColors.accentMauve,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: HiPopColors.errorPlum,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: HiPopColors.darkTextTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Application Deadline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDeadline,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.darkBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _applicationDeadline != null
                        ? '${_applicationDeadline!.month}/${_applicationDeadline!.day}/${_applicationDeadline!.year}'
                        : 'Select deadline date',
                    style: TextStyle(
                      color: _applicationDeadline != null
                          ? HiPopColors.darkTextPrimary
                          : HiPopColors.darkTextTertiary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: HiPopColors.darkTextTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_applicationDeadline != null) ...[
          const SizedBox(height: 4),
          Text(
            _getDeadlineHelperText(),
            style: TextStyle(
              fontSize: 12,
              color: _isDeadlineUrgent() 
                  ? HiPopColors.warningAmber 
                  : HiPopColors.darkTextTertiary,
            ),
          ),
        ],
      ],
    );
  }
  
  String _getDeadlineHelperText() {
    if (_applicationDeadline == null) return '';
    
    final daysUntil = _applicationDeadline!.difference(DateTime.now()).inDays;
    
    if (daysUntil <= 3) {
      return 'Urgent: Only $daysUntil days until deadline';
    } else if (daysUntil <= 7) {
      return 'Applications close in $daysUntil days';
    } else {
      return 'Applications open for $daysUntil days';
    }
  }
  
  bool _isDeadlineUrgent() {
    if (_applicationDeadline == null) return false;
    final daysUntil = _applicationDeadline!.difference(DateTime.now()).inDays;
    return daysUntil <= 3;
  }
}