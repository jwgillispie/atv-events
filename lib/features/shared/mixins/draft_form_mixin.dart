import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/form_draft.dart';
import '../services/drafts/form_draft_service.dart';
import '../widgets/drafts/draft_indicator_widget.dart';
import '../widgets/drafts/draft_recovery_dialog.dart';

/// Mixin to add draft functionality to any form screen
/// Handles auto-save, recovery, and UI indicators
mixin DraftFormMixin<T extends StatefulWidget> on State<T> {
  final FormDraftService _draftService = FormDraftService();

  // Draft state
  FormDraft? _currentDraft;
  Timer? _autoSaveTimer;
  bool _isSavingDraft = false;
  bool _hasUnsavedChanges = false;
  String? _draftId;

  // Override these in implementing class
  DraftType get draftType;
  Map<String, dynamic> get formData;
  List<String> get requiredFields => [];
  List<File> get localPhotos => [];
  List<String> get uploadedPhotoUrls => [];
  String? get associatedId => null;

  // Draft lifecycle methods
  @override
  void initState() {
    super.initState();
    _initializeDraft();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    // Save draft one final time if there are unsaved changes
    if (_hasUnsavedChanges && _currentDraft != null) {
      _draftService.saveDraft(_currentDraft!, immediate: true);
    }
    super.dispose();
  }

  /// Initialize draft system
  Future<void> _initializeDraft() async {
    // Check if draft ID was passed via navigation
    final args = GoRouterState.of(context).extra as Map<String, dynamic>?;
    _draftId = args?['draftId'];

    if (_draftId != null) {
      // Load specific draft
      await _loadDraft(_draftId!);
    } else {
      // Check for existing drafts
      await _checkForExistingDraft();
    }
  }

  /// Load a specific draft by ID
  Future<void> _loadDraft(String draftId) async {
    try {
      final draft = await _draftService.getDraft(draftId);
      if (draft != null) {
        setState(() {
          _currentDraft = draft;
        });
        await restoreFromDraft(draft);
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  /// Check for existing drafts and show recovery dialog
  Future<void> _checkForExistingDraft() async {
    try {
      final existingDraft = await _draftService.checkForExistingDraft(
        type: draftType,
        associatedId: associatedId,
      );

      if (existingDraft != null && mounted) {
        final action = await DraftRecoveryDialog.show(
          context,
          draft: existingDraft,
        );

        switch (action) {
          case DraftRecoveryAction.resume:
            setState(() {
              _currentDraft = existingDraft;
            });
            await restoreFromDraft(existingDraft);
            break;
          case DraftRecoveryAction.startFresh:
            // Delete the old draft and start new
            await _draftService.deleteDraft(existingDraft.id);
            _createNewDraft();
            break;
          case DraftRecoveryAction.viewAll:
            if (mounted) {
              context.push('/drafts');
            }
            break;
          case null:
            _createNewDraft();
            break;
        }
      } else {
        _createNewDraft();
      }
    } catch (e) {
      debugPrint('Error checking for existing draft: $e');
      _createNewDraft();
    }
  }

  /// Create a new draft
  void _createNewDraft() {
    setState(() {
      _currentDraft = _draftService.createDraft(
        type: draftType,
        formData: formData,
        associatedId: associatedId,
        photoUrls: uploadedPhotoUrls,
        localPhotoPaths: localPhotos.map((f) => f.path).toList(),
      );
    });
  }

  /// Mark that form has unsaved changes
  void markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
      _scheduleDraftSave();
    }
  }

  /// Schedule auto-save with debouncing
  void _scheduleDraftSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 3), _saveDraft);
  }

  /// Save the current draft
  Future<void> _saveDraft() async {
    if (_currentDraft == null) {
      _createNewDraft();
    }

    setState(() {
      _isSavingDraft = true;
    });

    try {
      final updatedDraft = _currentDraft!.copyWith(
        formData: formData,
        lastModified: DateTime.now(),
        photoUrls: uploadedPhotoUrls,
        localPhotoPaths: localPhotos.map((f) => f.path).toList(),
        completionPercentage: _calculateCompletion(),
        completedSections: _getCompletedSections(),
      );

      await _draftService.saveDraft(updatedDraft);

      setState(() {
        _currentDraft = updatedDraft;
        _hasUnsavedChanges = false;
        _isSavingDraft = false;
      });
    } catch (e) {
      debugPrint('Error saving draft: $e');
      setState(() {
        _isSavingDraft = false;
      });
    }
  }

  /// Calculate form completion percentage
  double _calculateCompletion() {
    if (requiredFields.isEmpty) return 0.0;

    int completedCount = 0;
    for (final field in requiredFields) {
      final value = formData[field];
      if (value != null) {
        if (value is String && value.isNotEmpty) {
          completedCount++;
        } else if (value is List && value.isNotEmpty) {
          completedCount++;
        } else if (value is! String && value is! List) {
          completedCount++;
        }
      }
    }

    return (completedCount / requiredFields.length) * 100;
  }

  /// Get completed sections map
  Map<String, bool> _getCompletedSections() {
    final sections = <String, bool>{};
    for (final field in requiredFields) {
      final value = formData[field];
      sections[field] = value != null &&
          (value is String ? value.isNotEmpty : true);
    }
    return sections;
  }

  /// Save draft immediately (for critical points)
  Future<void> saveDraftImmediately() async {
    _autoSaveTimer?.cancel();
    await _saveDraft();
  }

  /// Delete current draft
  Future<void> discardDraft() async {
    if (_currentDraft != null) {
      await _draftService.deleteDraft(_currentDraft!.id);
      setState(() {
        _currentDraft = null;
        _hasUnsavedChanges = false;
      });
    }
  }

  /// Build the draft indicator widget
  Widget buildDraftIndicator({bool showFullIndicator = true}) {
    return DraftIndicatorWidget(
      currentDraft: _currentDraft,
      isSaving: _isSavingDraft,
      hasUnsavedChanges: _hasUnsavedChanges,
      showFullIndicator: showFullIndicator,
      onViewDrafts: () => context.push('/drafts'),
      onDiscardDraft: () async {
        await discardDraft();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft discarded'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  /// Show draft saved snackbar
  void showDraftSavedMessage() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_done, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            const Text('Draft saved'),
            const Spacer(),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.push('/drafts');
              },
              child: const Text(
                'View Drafts',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Abstract method to restore form from draft
  /// Must be implemented by each form screen
  Future<void> restoreFromDraft(FormDraft draft);

  /// Helper to safely update text controller
  void updateTextController(TextEditingController controller, dynamic value) {
    if (value != null && value.toString().isNotEmpty) {
      controller.text = value.toString();
    }
  }

  /// Helper to restore date/time values
  DateTime? restoreDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Helper to restore bool values
  bool restoreBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return defaultValue;
  }

  /// Helper to restore list values
  List<T> restoreList<T>(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.cast<T>();
    return [];
  }
}