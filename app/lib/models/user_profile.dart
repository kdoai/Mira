/// User profile data model.
/// Ref: PLAN.md Section 5.6 (GET /profile), Section 6 (Firestore Schema)
library;

class UserProfile {
  final String name;
  final String email;
  final String? photoUrl;
  final String plan; // "free" | "pro"
  final int dailyMessagesUsed;
  final int dailyMessagesLimit;
  final double voiceMinutesUsed;
  final int voiceMinutesLimit;
  final String aboutMe;

  const UserProfile({
    required this.name,
    required this.email,
    this.photoUrl,
    this.plan = 'free',
    this.dailyMessagesUsed = 0,
    this.dailyMessagesLimit = 10,
    this.voiceMinutesUsed = 0,
    this.voiceMinutesLimit = 60,
    this.aboutMe = '',
  });

  bool get isPro => plan == 'pro';
  bool get hasReachedDailyLimit => dailyMessagesUsed >= dailyMessagesLimit;
  int get remainingMessages => dailyMessagesLimit - dailyMessagesUsed;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      plan: json['plan'] ?? 'free',
      dailyMessagesUsed: json['daily_messages_used'] ?? 0,
      dailyMessagesLimit: json['daily_messages_limit'] ?? 10,
      voiceMinutesUsed: (json['voice_minutes_used'] ?? 0).toDouble(),
      voiceMinutesLimit: json['voice_minutes_limit'] ?? 60,
      aboutMe: json['about_me'] ?? '',
    );
  }
}
