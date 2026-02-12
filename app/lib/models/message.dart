/// Chat message data model.
/// Ref: PLAN.md Section 6 (Firestore Schema)
library;

class ChatMessage {
  final String id;
  final String role; // "user" | "assistant" (maps to "model" for API)
  final String content;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessage({
    this.id = '',
    required this.role,
    required this.content,
    required this.timestamp,
    this.isStreaming = false,
  });

  /// Role value for API (Gemini uses "model" instead of "assistant")
  String get apiRole => role == 'assistant' ? 'model' : role;

  ChatMessage copyWith({
    String? id,
    String? role,
    String? content,
    DateTime? timestamp,
    bool? isStreaming,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'role': apiRole,
      'content': content,
    };
  }
}
