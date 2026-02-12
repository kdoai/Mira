/// Conversation data model.
/// Ref: PLAN.md Section 6 (Firestore Schema)
library;

class Conversation {
  final String id;
  final String coachId;
  final String coachName;
  final String type; // "text" | "voice"
  final String title;
  final String lastMessagePreview;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String nextAction;
  final String actionStatus; // "not_started" | "in_progress" | "done"
  final bool hasReport;
  final String reportSummary;

  const Conversation({
    required this.id,
    required this.coachId,
    required this.coachName,
    this.type = 'text',
    this.title = 'New conversation',
    this.lastMessagePreview = '',
    required this.createdAt,
    required this.updatedAt,
    this.messageCount = 0,
    this.nextAction = '',
    this.actionStatus = 'not_started',
    this.hasReport = false,
    this.reportSummary = '',
  });

  /// Whether this conversation has a real generated title (not the default).
  bool get hasGeneratedTitle =>
      title != 'New conversation' && title.isNotEmpty;

  /// Display title: proper title or generic label. Never uses preview as title.
  String get displayTitle {
    if (hasGeneratedTitle) return title;
    final label = type == 'voice' ? 'Voice session' : 'Session';
    return '$label with $coachName';
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      coachId: json['coach_id'] ?? '',
      coachName: json['coach_name'] ?? '',
      type: json['type'] ?? 'text',
      title: json['title'] ?? 'New conversation',
      lastMessagePreview: json['last_message_preview'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      messageCount: json['message_count'] ?? 0,
      nextAction: json['next_action'] ?? '',
      actionStatus: json['action_status'] ?? 'not_started',
      hasReport: json['has_report'] ?? false,
      reportSummary: json['report_summary'] ?? '',
    );
  }
}
