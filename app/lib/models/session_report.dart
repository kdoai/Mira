/// Session report data model.
/// Ref: PLAN.md Section 8.6 (Session Report Generation)
library;

class SessionReport {
  final String summary;
  final List<String> keyInsights;
  final List<String> actionItems;
  final String moodObservation;
  final DateTime generatedAt;

  const SessionReport({
    required this.summary,
    required this.keyInsights,
    required this.actionItems,
    required this.moodObservation,
    required this.generatedAt,
  });

  factory SessionReport.fromJson(Map<String, dynamic> json) {
    return SessionReport(
      summary: json['summary'] ?? '',
      keyInsights: List<String>.from(json['key_insights'] ?? []),
      actionItems: List<String>.from(json['action_items'] ?? []),
      moodObservation: json['mood_observation'] ?? '',
      generatedAt:
          DateTime.tryParse(json['generated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
