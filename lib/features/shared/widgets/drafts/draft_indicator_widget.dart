import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/hipop_colors.dart';
import '../../models/form_draft.dart';

/// Displays draft save status and provides quick actions
/// Shows auto-save indicator, last saved time, and sync status
class DraftIndicatorWidget extends StatefulWidget {
  final FormDraft? currentDraft;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final VoidCallback? onViewDrafts;
  final VoidCallback? onDiscardDraft;
  final bool showFullIndicator;

  const DraftIndicatorWidget({
    super.key,
    this.currentDraft,
    this.isSaving = false,
    this.hasUnsavedChanges = false,
    this.onViewDrafts,
    this.onDiscardDraft,
    this.showFullIndicator = true,
  });

  @override
  State<DraftIndicatorWidget> createState() => _DraftIndicatorWidgetState();
}

class _DraftIndicatorWidgetState extends State<DraftIndicatorWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void didUpdateWidget(DraftIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSaving != oldWidget.isSaving) {
      if (widget.isSaving) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.forward();
        // Provide haptic feedback on save
        HapticFeedback.lightImpact();
      }
    }
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

    if (!widget.showFullIndicator) {
      return _buildMinimalIndicator(isDarkMode);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? HiPopColors.darkSurfaceVariant.withOpacity(0.95)
            : HiPopColors.lightSurface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.3)
                : HiPopColors.lightShadow.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(isDarkMode),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusText(theme, isDarkMode),
                if (widget.currentDraft != null) ...[
                  const SizedBox(height: 4),
                  _buildLastSavedText(theme, isDarkMode),
                ],
              ],
            ),
          ),
          if (widget.onViewDrafts != null || widget.onDiscardDraft != null) ...[
            const SizedBox(width: 8),
            _buildActions(isDarkMode),
          ],
        ],
      ),
    );
  }

  Widget _buildMinimalIndicator(bool isDarkMode) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getStatusColor(isDarkMode).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getStatusColor(isDarkMode).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isSaving)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getStatusColor(isDarkMode),
                    ),
                  ),
                )
              else
                Icon(
                  _getStatusIcon(),
                  size: 14,
                  color: _getStatusColor(isDarkMode),
                ),
              const SizedBox(width: 6),
              Text(
                _getStatusText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _getStatusColor(isDarkMode),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(bool isDarkMode) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isSaving ? _scaleAnimation.value : 1.0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getStatusColor(isDarkMode).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: widget.isSaving
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getStatusColor(isDarkMode),
                        ),
                      ),
                    ),
                  )
                : Icon(
                    _getStatusIcon(),
                    size: 18,
                    color: _getStatusColor(isDarkMode),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatusText(ThemeData theme, bool isDarkMode) {
    return Text(
      _getStatusText(),
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: isDarkMode
            ? HiPopColors.darkTextPrimary
            : HiPopColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildLastSavedText(ThemeData theme, bool isDarkMode) {
    return Text(
      'Last saved ${widget.currentDraft!.ageDescription}',
      style: theme.textTheme.bodySmall?.copyWith(
        color: isDarkMode
            ? HiPopColors.darkTextTertiary
            : HiPopColors.lightTextTertiary,
      ),
    );
  }

  Widget _buildActions(bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onViewDrafts != null)
          IconButton(
            icon: Icon(
              Icons.folder_open,
              size: 20,
              color: HiPopColors.primaryDeepSage,
            ),
            onPressed: widget.onViewDrafts,
            tooltip: 'View all drafts',
            visualDensity: VisualDensity.compact,
          ),
        if (widget.onDiscardDraft != null)
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: HiPopColors.accentDustyPlum,
            ),
            onPressed: () => _showDiscardConfirmation(context),
            tooltip: 'Discard draft',
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  void _showDiscardConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: Text(
          'This will permanently delete your unsaved ${widget.currentDraft?.typeName ?? "form"} draft. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDiscardDraft?.call();
              HapticFeedback.mediumImpact();
            },
            style: TextButton.styleFrom(
              foregroundColor: HiPopColors.errorPlum,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    if (widget.isSaving) {
      return 'Saving draft...';
    } else if (widget.hasUnsavedChanges) {
      return 'Unsaved changes';
    } else if (widget.currentDraft != null) {
      if (widget.currentDraft!.status == DraftStatus.recovered) {
        return 'Draft recovered';
      }
      return 'Draft saved';
    }
    return 'No draft';
  }

  IconData _getStatusIcon() {
    if (widget.hasUnsavedChanges) {
      return Icons.edit_note;
    } else if (widget.currentDraft != null) {
      if (widget.currentDraft!.status == DraftStatus.recovered) {
        return Icons.restore;
      }
      return Icons.cloud_done;
    }
    return Icons.cloud_off;
  }

  Color _getStatusColor(bool isDarkMode) {
    if (widget.isSaving || widget.hasUnsavedChanges) {
      return HiPopColors.warningAmber;
    } else if (widget.currentDraft != null) {
      if (widget.currentDraft!.status == DraftStatus.recovered) {
        return HiPopColors.infoBlueGray;
      }
      return HiPopColors.successGreen;
    }
    return isDarkMode
        ? HiPopColors.darkTextTertiary
        : HiPopColors.lightTextTertiary;
  }
}