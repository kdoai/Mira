/// Chat state provider (Riverpod).
/// Ref: PLAN.md Section 5.1 (Text Chat SSE), Section 0.5 (Error Handling)
///
/// Manages chat messages and streaming state for a single conversation.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:mira/models/conversation.dart';
import 'package:mira/models/message.dart';
import 'package:mira/models/user_profile.dart';
import 'package:mira/providers/auth_provider.dart';
import 'package:mira/services/api_service.dart';

const _uuid = Uuid();

/// API service singleton
final apiServiceProvider = Provider<ApiService>((ref) {
  final authService = ref.watch(authServiceProvider);
  return ApiService(authService);
});

/// Current conversation ID
final conversationIdProvider = StateProvider<String>((ref) {
  return _uuid.v4();
});

/// Chat messages for current conversation
final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier(ref);
});

/// Whether AI is currently generating a response
final isStreamingProvider = StateProvider<bool>((ref) => false);

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  StreamSubscription? _streamSubscription;

  ChatMessagesNotifier(this._ref) : super([]);

  /// Send a message and receive streaming response.
  /// Ref: PLAN.md Section 5.1 (SSE streaming)
  Future<void> sendMessage(String coachId, String text) async {
    // Add user message
    final userMessage = ChatMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    state = [...state, userMessage];

    // Add placeholder for AI response
    final aiMessage = ChatMessage(
      role: 'assistant',
      content: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    state = [...state, aiMessage];
    _ref.read(isStreamingProvider.notifier).state = true;

    final apiService = _ref.read(apiServiceProvider);
    final conversationId = _ref.read(conversationIdProvider);

    // Build history (exclude the last empty AI message and the current user message)
    final history = state
        .where((m) => m.content.isNotEmpty && !m.isStreaming)
        .toList();
    // Remove the last user message from history (it's sent separately)
    if (history.isNotEmpty && history.last.role == 'user') {
      history.removeLast();
    }

    try {
      final stream = apiService.sendMessage(
        coachId: coachId,
        message: text,
        history: history,
        conversationId: conversationId,
      );

      String fullResponse = '';
      await for (final chunk in stream) {
        fullResponse += chunk;
        // Update the last message (AI response) with accumulated text
        final updated = state.last.copyWith(
          content: fullResponse,
          isStreaming: true,
        );
        state = [...state.sublist(0, state.length - 1), updated];
      }
      // Mark streaming as complete
      final final_ = state.last.copyWith(isStreaming: false);
      state = [...state.sublist(0, state.length - 1), final_];
    } catch (e) {
      // Show error in the AI message
      // Ref: PLAN.md Section 0.5 (Irregular Situation Handling)
      String errorText = "I'm having trouble thinking right now. Try again in a moment.";
      if (e is RateLimitException) {
        errorText = e.message;
      } else if (e is ApiException) {
        errorText = e.message;
      }
      final errorMsg = state.last.copyWith(
        content: errorText,
        isStreaming: false,
      );
      state = [...state.sublist(0, state.length - 1), errorMsg];
    } finally {
      _ref.read(isStreamingProvider.notifier).state = false;
    }
  }

  /// Load existing messages for a conversation (resume)
  Future<void> loadMessages(String conversationId) async {
    final apiService = _ref.read(apiServiceProvider);
    try {
      final messages = await apiService.getMessages(conversationId);
      state = messages;
    } catch (_) {
      // Keep empty state on error
    }
  }

  /// Start a new conversation
  void reset() {
    _streamSubscription?.cancel();
    state = [];
    _ref.read(conversationIdProvider.notifier).state = _uuid.v4();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

/// Conversations list — shared between Home (follow-up) and History screens.
/// Depends on authStateProvider so it auto-refreshes on user switch.
final conversationsProvider =
    FutureProvider<List<Conversation>>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return [];
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getConversations();
});

/// Latest conversation with a pending action item (for follow-up card).
final pendingFollowUpProvider = FutureProvider<Conversation?>((ref) async {
  final conversations = await ref.watch(conversationsProvider.future);
  try {
    return conversations.firstWhere(
      (c) => c.nextAction.isNotEmpty && c.actionStatus != 'done',
    );
  } catch (_) {
    return null;
  }
});

/// Active actions — conversations with pending action items (max 3).
/// Used by Journal screen Active Actions section.
final activeActionsProvider =
    FutureProvider<List<Conversation>>((ref) async {
  final conversations = await ref.watch(conversationsProvider.future);
  return conversations
      .where((c) => c.nextAction.isNotEmpty && c.actionStatus != 'done')
      .take(3)
      .toList();
});

/// User profile from backend (includes usage stats).
/// Depends on authStateProvider so it auto-refreshes on user switch.
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return UserProfile(name: '', email: '');
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getProfile();
});
