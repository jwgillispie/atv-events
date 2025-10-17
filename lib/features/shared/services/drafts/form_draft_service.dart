import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/form_draft.dart';

/// Service for managing form drafts with hybrid local/cloud persistence
/// Implements auto-save, recovery, and conflict resolution
class FormDraftService {
  static final FormDraftService _instance = FormDraftService._internal();
  factory FormDraftService() => _instance;
  FormDraftService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _draftsCollection = 'form_drafts';
  static const String _localStoragePrefix = 'hipop_draft_';
  static const int _autoSaveDelaySeconds = 3;
  static const int _maxDraftsPerType = 5;
  static const int _staleDraftDays = 30;

  Timer? _autoSaveTimer;
  final Map<String, Timer> _draftTimers = {};
  final Map<String, StreamController<FormDraft?>> _draftStreamControllers = {};

  /// Get current user ID
  String? get _userId => _auth.currentUser?.uid;

  /// Initialize service and clean up old drafts
  Future<void> initialize() async {
    await _cleanupStaleDrafts();
    await _syncLocalWithCloud();
  }

  /// Save draft with debounced auto-save
  Future<void> saveDraft(FormDraft draft, {bool immediate = false}) async {
    if (_userId == null) {
      await _saveLocalDraft(draft);
      return;
    }

    // Cancel existing timer for this draft
    _draftTimers[draft.id]?.cancel();

    if (immediate) {
      await _saveDraftToCloud(draft);
      await _saveLocalDraft(draft);
    } else {
      // Debounce saves to reduce write operations
      _draftTimers[draft.id] = Timer(
        Duration(seconds: _autoSaveDelaySeconds),
        () async {
          await _saveDraftToCloud(draft);
          await _saveLocalDraft(draft);
        },
      );
    }

    // Update stream
    _draftStreamControllers[draft.id]?.add(draft);
  }

  /// Save draft to Firestore
  Future<void> _saveDraftToCloud(FormDraft draft) async {
    try {
      final docRef = _firestore
          .collection(_draftsCollection)
          .doc(draft.id);

      await docRef.set(
        draft.toFirestore(),
        SetOptions(merge: true),
      );

      if (kDebugMode) {
        print('Draft saved to cloud: ${draft.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving draft to cloud: $e');
      }
      // Fall back to local storage
      await _saveLocalDraft(draft);
    }
  }

  /// Save draft to local storage
  Future<void> _saveLocalDraft(FormDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localStoragePrefix${draft.id}';
      await prefs.setString(key, jsonEncode(draft.toJson()));

      // Update index of local drafts
      await _updateLocalDraftIndex(draft.id, draft.type);

      if (kDebugMode) {
        print('Draft saved locally: ${draft.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving draft locally: $e');
      }
    }
  }

  /// Update local draft index for quick retrieval
  Future<void> _updateLocalDraftIndex(String draftId, DraftType type) async {
    final prefs = await SharedPreferences.getInstance();
    final indexKey = '${_localStoragePrefix}index_${type.toString()}';
    final existingIndex = prefs.getStringList(indexKey) ?? [];

    if (!existingIndex.contains(draftId)) {
      existingIndex.insert(0, draftId);

      // Limit number of drafts per type
      if (existingIndex.length > _maxDraftsPerType) {
        final removedIds = existingIndex.sublist(_maxDraftsPerType);
        existingIndex.removeRange(_maxDraftsPerType, existingIndex.length);

        // Clean up removed drafts
        for (final id in removedIds) {
          await prefs.remove('$_localStoragePrefix$id');
        }
      }

      await prefs.setStringList(indexKey, existingIndex);
    }
  }

  /// Get draft by ID
  Future<FormDraft?> getDraft(String draftId) async {
    // Try cloud first if authenticated
    if (_userId != null) {
      try {
        final doc = await _firestore
            .collection(_draftsCollection)
            .doc(draftId)
            .get();

        if (doc.exists) {
          return FormDraft.fromFirestore(doc);
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching draft from cloud: $e');
        }
      }
    }

    // Fall back to local storage
    return await _getLocalDraft(draftId);
  }

  /// Get draft from local storage
  Future<FormDraft?> _getLocalDraft(String draftId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localStoragePrefix$draftId';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        return FormDraft.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching local draft: $e');
      }
    }
    return null;
  }

  /// Get all drafts for current user
  Future<List<FormDraft>> getUserDrafts({DraftType? type}) async {
    final drafts = <FormDraft>[];

    // Get cloud drafts if authenticated
    if (_userId != null) {
      try {
        Query query = _firestore
            .collection(_draftsCollection)
            .where('userId', isEqualTo: _userId)
            .orderBy('lastModified', descending: true);

        if (type != null) {
          query = query.where('type', isEqualTo: type.toString());
        }

        final snapshot = await query.limit(20).get();
        drafts.addAll(
          snapshot.docs.map((doc) => FormDraft.fromFirestore(doc)),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching cloud drafts: $e');
        }
      }
    }

    // Merge with local drafts
    final localDrafts = await _getLocalDrafts(type: type);
    for (final localDraft in localDrafts) {
      // Avoid duplicates
      if (!drafts.any((d) => d.id == localDraft.id)) {
        drafts.add(localDraft);
      }
    }

    // Sort by last modified
    drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    return drafts;
  }

  /// Get local drafts
  Future<List<FormDraft>> _getLocalDrafts({DraftType? type}) async {
    final drafts = <FormDraft>[];
    final prefs = await SharedPreferences.getInstance();

    final types = type != null ? [type] : DraftType.values;

    for (final draftType in types) {
      final indexKey = '${_localStoragePrefix}index_${draftType.toString()}';
      final draftIds = prefs.getStringList(indexKey) ?? [];

      for (final id in draftIds) {
        final draft = await _getLocalDraft(id);
        if (draft != null && !draft.isStale) {
          drafts.add(draft);
        }
      }
    }

    return drafts;
  }

  /// Stream draft changes
  Stream<FormDraft?> streamDraft(String draftId) {
    // Create stream controller if not exists
    _draftStreamControllers[draftId] ??= StreamController<FormDraft?>.broadcast();

    if (_userId != null) {
      // Stream from Firestore
      _firestore
          .collection(_draftsCollection)
          .doc(draftId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final draft = FormDraft.fromFirestore(snapshot);
          _draftStreamControllers[draftId]?.add(draft);
        } else {
          _draftStreamControllers[draftId]?.add(null);
        }
      });
    }

    return _draftStreamControllers[draftId]!.stream;
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    // Cancel any pending saves
    _draftTimers[draftId]?.cancel();
    _draftTimers.remove(draftId);

    // Delete from cloud
    if (_userId != null) {
      try {
        await _firestore
            .collection(_draftsCollection)
            .doc(draftId)
            .delete();
      } catch (e) {
        if (kDebugMode) {
          print('Error deleting cloud draft: $e');
        }
      }
    }

    // Delete from local storage
    await _deleteLocalDraft(draftId);

    // Close stream
    _draftStreamControllers[draftId]?.close();
    _draftStreamControllers.remove(draftId);
  }

  /// Delete local draft
  Future<void> _deleteLocalDraft(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_localStoragePrefix$draftId');

    // Update indices
    for (final type in DraftType.values) {
      final indexKey = '${_localStoragePrefix}index_${type.toString()}';
      final draftIds = prefs.getStringList(indexKey) ?? [];
      draftIds.remove(draftId);
      await prefs.setStringList(indexKey, draftIds);
    }
  }

  /// Clean up stale drafts (older than 30 days)
  Future<void> _cleanupStaleDrafts() async {
    final cutoffDate = DateTime.now().subtract(Duration(days: _staleDraftDays));

    // Clean cloud drafts
    if (_userId != null) {
      try {
        final snapshot = await _firestore
            .collection(_draftsCollection)
            .where('userId', isEqualTo: _userId)
            .where('lastModified', isLessThan: Timestamp.fromDate(cutoffDate))
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }

        if (kDebugMode && snapshot.docs.isNotEmpty) {
          print('Cleaned up ${snapshot.docs.length} stale cloud drafts');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error cleaning stale cloud drafts: $e');
        }
      }
    }

    // Clean local drafts
    final localDrafts = await _getLocalDrafts();
    for (final draft in localDrafts) {
      if (draft.isStale) {
        await _deleteLocalDraft(draft.id);
      }
    }
  }

  /// Sync local drafts with cloud when user logs in
  Future<void> _syncLocalWithCloud() async {
    if (_userId == null) return;

    final localDrafts = await _getLocalDrafts();
    for (final draft in localDrafts) {
      // Update userId if different
      if (draft.userId != _userId) {
        final updatedDraft = draft.copyWith(userId: _userId);
        await _saveDraftToCloud(updatedDraft);
      } else {
        // Check for conflicts
        final cloudDraft = await getDraft(draft.id);
        if (cloudDraft != null) {
          // Resolve conflict - keep most recent
          if (draft.lastModified.isAfter(cloudDraft.lastModified)) {
            await _saveDraftToCloud(draft);
          }
        } else {
          // Upload local draft to cloud
          await _saveDraftToCloud(draft);
        }
      }
    }
  }

  /// Create a new draft ID
  String generateDraftId() {
    return const Uuid().v4();
  }

  /// Convert existing form data to draft
  FormDraft createDraft({
    required DraftType type,
    required Map<String, dynamic> formData,
    String? associatedId,
    List<String>? photoUrls,
    List<String>? localPhotoPaths,
  }) {
    return FormDraft(
      id: generateDraftId(),
      userId: _userId ?? 'anonymous',
      type: type,
      formData: formData,
      photoUrls: photoUrls ?? [],
      localPhotoPaths: localPhotoPaths ?? [],
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      associatedId: associatedId,
      status: DraftStatus.inProgress,
    );
  }

  /// Check for existing drafts on form load
  Future<FormDraft?> checkForExistingDraft({
    required DraftType type,
    String? associatedId,
  }) async {
    final drafts = await getUserDrafts(type: type);

    if (associatedId != null) {
      // Check for draft of same entity
      final associatedDrafts = drafts.where(
        (d) => d.associatedId == associatedId,
      );
      if (associatedDrafts.isNotEmpty) {
        return associatedDrafts.first;
      }
    }

    // Return most recent draft of this type
    if (drafts.isNotEmpty && drafts.first.isRecent) {
      return drafts.first;
    }

    return null;
  }

  /// Clear all drafts for current user
  Future<void> clearAllDrafts() async {
    final drafts = await getUserDrafts();
    for (final draft in drafts) {
      await deleteDraft(draft.id);
    }
  }

  /// Dispose of resources
  void dispose() {
    for (final timer in _draftTimers.values) {
      timer.cancel();
    }
    _draftTimers.clear();

    for (final controller in _draftStreamControllers.values) {
      controller.close();
    }
    _draftStreamControllers.clear();

    _autoSaveTimer?.cancel();
  }
}