/// Coaches state provider (Riverpod).
/// Ref: PLAN.md Section 3.4, 3.5 (Coach Decisions, Custom Coaches)
///
/// Provides built-in coaches + user's custom coaches.
/// Custom coaches are loaded from backend on init and persist across restarts.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/models/coach.dart';
import 'package:mira/services/api_service.dart';

/// All available coaches (built-in + custom)
final coachesProvider =
    StateNotifierProvider<CoachesNotifier, List<Coach>>((ref) {
  return CoachesNotifier();
});

class CoachesNotifier extends StateNotifier<List<Coach>> {
  CoachesNotifier() : super(Coach.builtIn);

  /// Load custom coaches from backend. Call after auth.
  Future<void> loadCustomCoaches(ApiService api) async {
    try {
      final coachMaps = await api.getMyCoaches();
      final custom = coachMaps.map((c) => Coach.fromJson(c)).toList();
      // Merge: built-in + custom (deduplicate by id)
      final existingIds = Coach.builtIn.map((c) => c.id).toSet();
      final newCustom = custom.where((c) => !existingIds.contains(c.id)).toList();
      state = [...Coach.builtIn, ...newCustom];
    } catch (_) {
      // Keep built-in only on error
    }
  }

  /// Add a custom coach
  void addCoach(Coach coach) {
    state = [...state, coach];
  }

  /// Get coach by ID
  Coach? getCoach(String id) {
    try {
      return state.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
