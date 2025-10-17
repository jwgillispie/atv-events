import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/customer_feedback.dart';
import '../../constants/rating_constants.dart';
import 'package:atv_events/core/theme/atv_colors.dart';
import '../common/loading_widget.dart';

/// Base class for all rating forms to extend
abstract class BaseRatingForm extends StatefulWidget {
  final String targetId;
  final String? targetName;
  final DateTime visitDate;
  final FeedbackTarget feedbackTarget;
  final String? marketId;
  final String? eventId;

  const BaseRatingForm({
    super.key,
    required this.targetId,
    this.targetName,
    required this.visitDate,
    required this.feedbackTarget,
    this.marketId,
    this.eventId,
  });
}

/// Base state class with common rating form functionality
abstract class BaseRatingFormState<T extends BaseRatingForm> extends State<T> {
  // Form controllers
  final formKey = GlobalKey<FormState>();
  final reviewController = TextEditingController();
  final spendAmountController = TextEditingController();
  
  // Rating state
  int overallRating = 0;
  Map<ReviewCategory, int> categoryRatings = {};
  bool isAnonymous = false;
  bool wouldRecommend = false;
  int? npsScore;
  bool madeAPurchase = false;
  List<String> selectedTags = [];
  Duration? timeSpent;
  bool isSubmitting = false;
  
  // Abstract methods to be implemented by subclasses
  List<ReviewCategory> get reviewCategories;
  List<String> get availableTags;
  String get submitButtonText;
  String get screenTitle;
  String get headerIcon => getHeaderIcon();
  Color get headerColor => getHeaderColor();
  
  @override
  void dispose() {
    reviewController.dispose();
    spendAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: Text(screenTitle),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isSubmitting
          ? LoadingWidget(message: 'Submitting your ${widget.feedbackTarget.name}...')
          : buildForm(),
    );
  }

  /// Build the main form
  Widget buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildHeader(),
            const SizedBox(height: 24),
            ...buildFormSections(),
            const SizedBox(height: 32),
            buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  /// Build the header section
  Widget buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            headerColor,
            headerColor.withOpacity( 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                getIconData(),
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.targetName ?? 'Experience',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Visited on ${formatDate(widget.visitDate)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity( 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            getHeaderSubtitle(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// Build form sections - override to customize
  List<Widget> buildFormSections() {
    return [
      buildOverallRatingSection(),
      const SizedBox(height: 24),
      buildCategoryRatingsSection(),
      const SizedBox(height: 24),
      buildPurchaseSection(),
      const SizedBox(height: 24),
      buildRecommendationSection(),
      const SizedBox(height: 24),
      buildWrittenReviewSection(),
      const SizedBox(height: 24),
      buildTagsSection(),
      const SizedBox(height: 24),
      buildTimeSpentSection(),
      const SizedBox(height: 24),
      buildPrivacySection(),
    ];
  }

  /// Override these methods in subclasses for customization
  Widget buildOverallRatingSection();
  Widget buildCategoryRatingsSection();
  Widget buildPurchaseSection();
  Widget buildRecommendationSection();
  Widget buildWrittenReviewSection();
  Widget buildTagsSection();
  Widget buildTimeSpentSection();
  
  /// Common privacy section
  Widget buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Options',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Submit anonymously'),
          subtitle: Text('Your identity will not be shared with the ${widget.feedbackTarget.name}'),
          value: isAnonymous,
          onChanged: (value) {
            setState(() {
              isAnonymous = value;
            });
          },
          activeColor: headerColor,
        ),
      ],
    );
  }

  /// Submit button
  Widget buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: overallRating > 0 ? submitRating : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: headerColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: Text(
          submitButtonText,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Submit rating to Firestore
  Future<void> submitRating() async {
    if (!formKey.currentState!.validate()) return;

    setState(() {
      isSubmitting = true;
    });

    try {
      final feedback = buildFeedback();
      await saveFeedback(feedback);
      
      if (mounted) {
        showSuccessMessage();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        showErrorMessage(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  /// Build the feedback object
  CustomerFeedback buildFeedback() {
    final user = FirebaseAuth.instance.currentUser;
    final sessionId = '${DateTime.now().millisecondsSinceEpoch}_${user?.uid ?? 'anonymous'}';
    
    return CustomerFeedback(
      id: '',
      userId: isAnonymous ? null : user?.uid,
      marketId: widget.marketId,
      vendorId: widget.feedbackTarget == FeedbackTarget.vendor ? widget.targetId : null,
      eventId: widget.eventId,
      target: widget.feedbackTarget,
      overallRating: overallRating,
      categoryRatings: categoryRatings,
      reviewText: reviewController.text.isNotEmpty ? reviewController.text : null,
      isAnonymous: isAnonymous,
      visitDate: widget.visitDate,
      createdAt: DateTime.now(),
      tags: selectedTags.isNotEmpty ? selectedTags : null,
      wouldRecommend: wouldRecommend,
      npsScore: npsScore,
      sessionId: sessionId,
      timeSpentAtVendor: widget.feedbackTarget == FeedbackTarget.vendor ? timeSpent : null,
      timeSpentAtMarket: widget.feedbackTarget == FeedbackTarget.market ? timeSpent : null,
      madeAPurchase: madeAPurchase,
      estimatedSpendAmount: spendAmountController.text.isNotEmpty 
          ? double.tryParse(spendAmountController.text) 
          : null,
    );
  }

  /// Save feedback to Firestore
  Future<void> saveFeedback(CustomerFeedback feedback) async {
    await FirebaseFirestore.instance
        .collection('customer_feedback')
        .add(feedback.toFirestore());
  }

  /// Show success message
  void showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(RatingConstants.successMessages[widget.feedbackTarget]!),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Show error message
  void showErrorMessage(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error submitting rating: $error'),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Helper methods
  String formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String getHeaderIcon() {
    switch (widget.feedbackTarget) {
      case FeedbackTarget.vendor:
        return 'store';
      case FeedbackTarget.market:
        return 'storefront';
      case FeedbackTarget.event:
        return 'event';
      case FeedbackTarget.overall:
        return 'star';
    }
  }

  IconData getIconData() {
    switch (widget.feedbackTarget) {
      case FeedbackTarget.vendor:
        return Icons.store;
      case FeedbackTarget.market:
        return Icons.storefront;
      case FeedbackTarget.event:
        return Icons.event;
      case FeedbackTarget.overall:
        return Icons.star;
    }
  }

  Color getHeaderColor() {
    switch (widget.feedbackTarget) {
      case FeedbackTarget.vendor:
        return HiPopColors.vendorAccent;
      case FeedbackTarget.market:
        return HiPopColors.shopperAccent;
      case FeedbackTarget.event:
        return HiPopColors.accentMauve;
      case FeedbackTarget.overall:
        return HiPopColors.primaryDeepSage;
    }
  }

  String getHeaderSubtitle() {
    switch (widget.feedbackTarget) {
      case FeedbackTarget.vendor:
        return 'Your feedback helps vendors improve their service';
      case FeedbackTarget.market:
        return 'Help us improve the market experience';
      case FeedbackTarget.event:
        return 'Share your thoughts about this event';
      case FeedbackTarget.overall:
        return 'Your overall experience matters to us';
    }
  }
}