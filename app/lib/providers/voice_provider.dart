/// Voice session state provider (Riverpod).
/// Ref: PLAN.md Section 5.2 (Voice Session)
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/providers/auth_provider.dart';
import 'package:mira/services/voice_service.dart';

/// Voice service singleton
final voiceServiceProvider = Provider<VoiceService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return VoiceService(authService);
});

/// Whether voice session is active
final isVoiceActiveProvider = StateProvider<bool>((ref) => false);

/// Whether mic is currently listening (false = AI is speaking, mic muted)
final isMicListeningProvider = StateProvider<bool>((ref) => true);

/// Voice transcripts (role + text pairs)
final voiceTranscriptsProvider =
    StateNotifierProvider<VoiceTranscriptsNotifier, List<VoiceTranscript>>(
        (ref) {
  return VoiceTranscriptsNotifier();
});

class VoiceTranscript {
  final String role;
  final String text;

  const VoiceTranscript({required this.role, required this.text});
}

class VoiceTranscriptsNotifier extends StateNotifier<List<VoiceTranscript>> {
  VoiceTranscriptsNotifier() : super([]);

  /// Add or append transcript text.
  /// Gemini sends incremental fragments for the same speaker turn.
  /// If last entry is same role, concatenate; otherwise add new entry.
  void add(String role, String text) {
    if (state.isNotEmpty && state.last.role == role) {
      final updated = VoiceTranscript(
        role: role,
        text: state.last.text + text,
      );
      state = [...state.sublist(0, state.length - 1), updated];
    } else {
      state = [...state, VoiceTranscript(role: role, text: text)];
    }
  }

  /// Force a new entry (e.g., after AI finishes speaking, next fragment starts fresh).
  void finishTurn() {
    // No-op marker; next add with different role auto-creates new entry.
  }

  void clear() {
    state = [];
  }
}
