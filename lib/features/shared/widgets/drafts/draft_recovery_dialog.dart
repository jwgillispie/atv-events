import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';
import '../../models/form_draft.dart';

/// Dialog shown when a draft is detected for recovery
/// Provides options to resume, start fresh, or view all drafts
class DraftRecoveryDialog extends StatelessWidget {
  final FormDraft draft;
  final VoidCallback onResume;
  final VoidCallback onStartFresh;
  final VoidCallback? onViewAllDrafts;

  const DraftRecoveryDialog({
    super.key,
    required this.draft,
    required this.onResume,
    required this.onStartFresh,
    this.onViewAllDrafts,
  });

  static Future<DraftRecoveryAction?> show(
    BuildContext context, {
    required FormDraft draft,
  }) async {
    return showDialog<DraftRecoveryAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DraftRecoveryDialogContent(draft: draft),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DraftRecoveryDialogContent(draft: draft);
  }
}

class _DraftRecoveryDialogContent extends StatefulWidget {
  final FormDraft draft;

  const _DraftRecoveryDialogContent({
    required this.draft,
  });

  @override
  State<_DraftRecoveryDialogContent> createState() =>
      _DraftRecoveryDialogContentState();
}

class _DraftRecoveryDialogContentState
    extends State<_DraftRecoveryDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 24,
              backgroundColor: isDarkMode
                  ? HiPopColors.darkSurface
                  : HiPopColors.lightBackground,
              child: Container(
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(theme, isDarkMode),
                    const SizedBox(height: 20),
                    _buildDraftInfo(theme, isDarkMode),
                    const SizedBox(height: 24),
                    _buildActions(context, theme, isDarkMode),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: widget.draft.type.color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.restore_page,
            size: 32,
            color: widget.draft.type.color,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Resume ${widget.draft.typeName} Draft?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? HiPopColors.darkTextPrimary
                : HiPopColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We found an unsaved draft from ${widget.draft.ageDescription}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDarkMode
                ? HiPopColors.darkTextSecondary
                : HiPopColors.lightTextSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDraftInfo(ThemeData theme, bool isDarkMode) {
    final completionPercentage = widget.draft.completionPercentage;
    final hasTitle = widget.draft.formData['name'] != null ||
        widget.draft.formData['vendorName'] != null;
    final title = widget.draft.formData['name'] ??
        widget.draft.formData['vendorName'] ??
        'Untitled ${widget.draft.typeName}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? HiPopColors.darkSurfaceVariant.withOpacity(0.5)
            : HiPopColors.lightSurfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? HiPopColors.darkBorder
              : HiPopColors.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.draft.type.icon,
                size: 20,
                color: widget.draft.type.color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? HiPopColors.darkTextPrimary
                        : HiPopColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProgressIndicator(completionPercentage, isDarkMode),
          const SizedBox(height: 8),
          _buildDraftDetails(theme, isDarkMode),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double percentage, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode
                    ? HiPopColors.darkTextTertiary
                    : HiPopColors.lightTextTertiary,
              ),
            ),
            Text(
              '${percentage.toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getProgressColor(percentage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 6,
            backgroundColor: isDarkMode
                ? HiPopColors.darkBorder
                : HiPopColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(percentage),
            ),
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 80) {
      return HiPopColors.successGreen;
    } else if (percentage >= 50) {
      return HiPopColors.warningAmber;
    } else {
      return HiPopColors.infoBlueGray;
    }
  }

  Widget _buildDraftDetails(ThemeData theme, bool isDarkMode) {
    final details = <String, dynamic>{};

    // Extract key details based on draft type
    switch (widget.draft.type) {
      case DraftType.popup:
        details['Location'] = widget.draft.formData['location'];
        details['Date'] = widget.draft.formData['popUpStartDateTime'];
        details['Photos'] = widget.draft.photoUrls.length +
            widget.draft.localPhotoPaths.length;
        break;
      case DraftType.market:
        details['Location'] = widget.draft.formData['location'];
        details['Operating Hours'] = widget.draft.formData['operatingHours'];
        break;
      case DraftType.event:
        details['Location'] = widget.draft.formData['location'];
        details['Start Date'] = widget.draft.formData['startDateTime'];
        details['Tickets'] = widget.draft.formData['hasTicketing'] == true
            ? 'Enabled'
            : 'Disabled';
        break;
    }

    final validDetails = details.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .take(3)
        .toList();

    if (validDetails.isEmpty) {
      return Text(
        'No details saved yet',
        style: TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.italic,
          color: isDarkMode
              ? HiPopColors.darkTextTertiary
              : HiPopColors.lightTextTertiary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: validDetails.map((entry) {
        String value = entry.value.toString();
        if (entry.value is DateTime) {
          final date = entry.value as DateTime;
          value = '${date.month}/${date.day}/${date.year}';
        } else if (entry.key == 'Photos' && entry.value > 0) {
          value = '${entry.value} added';
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.key}: ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode
                      ? HiPopColors.darkTextTertiary
                      : HiPopColors.lightTextTertiary,
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode
                        ? HiPopColors.darkTextSecondary
                        : HiPopColors.lightTextSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActions(BuildContext context, ThemeData theme, bool isDarkMode) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(DraftRecoveryAction.resume);
            },
            icon: const Icon(Icons.restore, size: 20),
            label: const Text('Resume Draft'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop(DraftRecoveryAction.startFresh);
            },
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Start Fresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDarkMode
                  ? HiPopColors.darkTextPrimary
                  : HiPopColors.lightTextPrimary,
              side: BorderSide(
                color: isDarkMode
                    ? HiPopColors.darkBorder
                    : HiPopColors.lightBorder,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop(DraftRecoveryAction.viewAll);
          },
          child: Text(
            'View All Drafts',
            style: TextStyle(
              color: HiPopColors.primaryDeepSage,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

enum DraftRecoveryAction {
  resume,
  startFresh,
  viewAll,
}