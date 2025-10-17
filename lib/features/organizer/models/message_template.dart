import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class MessageTemplate extends Equatable {
  final String id;
  final String organizerId;
  final String name;
  final String subject;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int usageCount;
  final Map<String, dynamic> metadata;

  const MessageTemplate({
    required this.id,
    required this.organizerId,
    required this.name,
    required this.subject,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.usageCount = 0,
    this.metadata = const {},
  });

  factory MessageTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageTemplate(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      name: data['name'] ?? '',
      subject: data['subject'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'general',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usageCount: data['usageCount'] ?? 0,
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'name': name,
      'subject': subject,
      'content': content,
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'usageCount': usageCount,
      'metadata': metadata,
    };
  }

  MessageTemplate copyWith({
    String? id,
    String? organizerId,
    String? name,
    String? subject,
    String? content,
    String? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? usageCount,
    Map<String, dynamic>? metadata,
  }) {
    return MessageTemplate(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      name: name ?? this.name,
      subject: subject ?? this.subject,
      content: content ?? this.content,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      usageCount: usageCount ?? this.usageCount,
      metadata: metadata ?? this.metadata,
    );
  }

  MessageTemplate incrementUsage() {
    return copyWith(
      usageCount: usageCount + 1,
      updatedAt: DateTime.now(),
    );
  }

  /// Replace template variables with actual values
  String processContent(Map<String, String> variables) {
    String processedContent = content;
    for (final entry in variables.entries) {
      processedContent = processedContent.replaceAll(
        '{${entry.key}}',
        entry.value,
      );
    }
    return processedContent;
  }

  /// Replace template variables in subject line
  String processSubject(Map<String, String> variables) {
    String processedSubject = subject;
    for (final entry in variables.entries) {
      processedSubject = processedSubject.replaceAll(
        '{${entry.key}}',
        entry.value,
      );
    }
    return processedSubject;
  }

  /// Get all variables used in the template
  List<String> getUsedVariables() {
    final variables = <String>[];
    final RegExp variableRegex = RegExp(r'\{([^}]+)\}');
    
    // Extract variables from subject
    final subjectMatches = variableRegex.allMatches(subject);
    for (final match in subjectMatches) {
      final variable = match.group(1);
      if (variable != null && !variables.contains(variable)) {
        variables.add(variable);
      }
    }
    
    // Extract variables from content
    final contentMatches = variableRegex.allMatches(content);
    for (final match in contentMatches) {
      final variable = match.group(1);
      if (variable != null && !variables.contains(variable)) {
        variables.add(variable);
      }
    }
    
    return variables;
  }

  @override
  List<Object?> get props => [
        id,
        organizerId,
        name,
        subject,
        content,
        category,
        createdAt,
        updatedAt,
        usageCount,
        metadata,
      ];

  @override
  String toString() {
    return 'MessageTemplate(id: $id, organizerId: $organizerId, name: $name, category: $category)';
  }
}

/// Predefined template categories
enum TemplateCategory {
  general,
  eventAnnouncement,
  policyUpdate,
  marketInvitation,
  reminder,
  welcome,
  seasonal,
}

extension TemplateCategoryExtension on TemplateCategory {
  String get displayName {
    switch (this) {
      case TemplateCategory.general:
        return 'General';
      case TemplateCategory.eventAnnouncement:
        return 'Event Announcement';
      case TemplateCategory.policyUpdate:
        return 'Policy Update';
      case TemplateCategory.marketInvitation:
        return 'Market Invitation';
      case TemplateCategory.reminder:
        return 'Reminder';
      case TemplateCategory.welcome:
        return 'Welcome';
      case TemplateCategory.seasonal:
        return 'Seasonal';
    }
  }

  String get key {
    switch (this) {
      case TemplateCategory.general:
        return 'general';
      case TemplateCategory.eventAnnouncement:
        return 'event';
      case TemplateCategory.policyUpdate:
        return 'policy';
      case TemplateCategory.marketInvitation:
        return 'invitation';
      case TemplateCategory.reminder:
        return 'reminder';
      case TemplateCategory.welcome:
        return 'welcome';
      case TemplateCategory.seasonal:
        return 'seasonal';
    }
  }

  static TemplateCategory fromKey(String key) {
    switch (key) {
      case 'general':
        return TemplateCategory.general;
      case 'event':
        return TemplateCategory.eventAnnouncement;
      case 'policy':
        return TemplateCategory.policyUpdate;
      case 'invitation':
        return TemplateCategory.marketInvitation;
      case 'reminder':
        return TemplateCategory.reminder;
      case 'welcome':
        return TemplateCategory.welcome;
      case 'seasonal':
        return TemplateCategory.seasonal;
      default:
        return TemplateCategory.general;
    }
  }
}

/// Predefined message templates for common communications
class DefaultTemplates {
  static List<MessageTemplate> getDefaultTemplates(String organizerId) {
    final now = DateTime.now();
    
    return [
      MessageTemplate(
        id: '',
        organizerId: organizerId,
        name: 'Welcome New Vendor',
        subject: 'Welcome to {market_name}!',
        content: '''Dear {vendor_name},

Welcome to our farmers market community! We're excited to have you join us at {market_name}.

Here are some important details to get you started:
• Market hours: Please arrive 30 minutes before opening
• Setup requirements: Follow our vendor guidelines
• Payment processing: We accept cash and cards
• Contact us: Reach out with any questions

We look forward to working with you and helping your business grow!

Best regards,
{organizer_name}''',
        category: TemplateCategory.welcome.key,
        createdAt: now,
        updatedAt: now,
      ),
      
      MessageTemplate(
        id: '',
        organizerId: organizerId,
        name: 'Market Event Announcement',
        subject: 'Special Event: {event_name} at {market_name}',
        content: '''Hi {vendor_name},

We have an exciting announcement! We're hosting {event_name} on {event_date} at {market_name}.

Event details:
• Date: {event_date}
• Special theme: {event_theme}
• Expected attendance: Higher than usual
• Additional setup time: Please arrive early

This is a great opportunity to showcase your products to more customers. Please confirm your participation by replying to this message.

Looking forward to a successful event!

{organizer_name}''',
        category: TemplateCategory.eventAnnouncement.key,
        createdAt: now,
        updatedAt: now,
      ),
      
      MessageTemplate(
        id: '',
        organizerId: organizerId,
        name: 'Policy Update Notification',
        subject: 'Important Policy Update - {market_name}',
        content: '''Dear {vendor_name},

We're writing to inform you of an important policy update at {market_name}.

Policy change: {policy_details}

Effective date: {effective_date}

Please review these changes and ensure compliance. If you have any questions or concerns, please don't hesitate to contact us.

Thank you for your continued cooperation.

Best regards,
{organizer_name}''',
        category: TemplateCategory.policyUpdate.key,
        createdAt: now,
        updatedAt: now,
      ),
      
      MessageTemplate(
        id: '',
        organizerId: organizerId,
        name: 'Market Day Reminder',
        subject: 'Reminder: Market Day Tomorrow at {market_name}',
        content: '''Hi {vendor_name},

This is a friendly reminder that {market_name} is tomorrow!

Market details:
• Date: {market_date}
• Setup time: {setup_time}
• Market hours: {market_hours}
• Weather forecast: {weather}

Please remember to:
✓ Arrive on time for setup
✓ Bring all necessary equipment
✓ Have your permit and insurance ready
✓ Follow health and safety guidelines

See you tomorrow!

{organizer_name}''',
        category: TemplateCategory.reminder.key,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}