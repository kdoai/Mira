/// Chat screen — text conversation with AI coach.
/// Ref: PLAN.md Section 5.1 (SSE streaming), Section 0.8 (Production Quality)
///
/// Notion-inspired: clean, breathable, content-first layout.
/// Features:
/// - Streaming AI responses (SSE)
/// - Minimal suggestion chips on empty chat
/// - Auto-scroll to bottom on new messages
/// - Send button disabled when empty
/// - Coach name in app bar
/// - Voice button for Pro users
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:mira/models/coach.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/providers/subscription_provider.dart';
import 'package:mira/theme/app_theme.dart';
import 'package:mira/widgets/message_bubble.dart';

const _uuid = Uuid();

class ChatScreen extends ConsumerStatefulWidget {
  final String coachId;
  final String? conversationId;

  const ChatScreen({
    super.key,
    required this.coachId,
    this.conversationId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  late String _conversationId;

  @override
  void initState() {
    super.initState();

    if (widget.conversationId != null) {
      // Resuming existing conversation
      _conversationId = widget.conversationId!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(conversationIdProvider.notifier).state = _conversationId;
        ref.read(chatMessagesProvider.notifier).loadMessages(_conversationId);
      });
    } else {
      // New conversation
      _conversationId = _uuid.v4();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(conversationIdProvider.notifier).state = _conversationId;
        ref.read(chatMessagesProvider.notifier).reset();
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Coach? get _coach {
    return ref.read(coachesProvider.notifier).getCoach(widget.coachId);
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    ref.read(chatMessagesProvider.notifier).sendMessage(widget.coachId, text.trim());
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final coach = _coach;
    final isPro = ref.watch(isProProvider);

    // Auto-scroll when messages change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coach != null)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: coach.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(coach.icon, color: coach.color, size: 16),
              ),
            const SizedBox(width: MiraSpacing.sm),
            Text(coach?.name ?? widget.coachId),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/voice/${widget.coachId}');
            },
            icon: const Icon(Icons.mic_outlined),
            tooltip: 'Switch to voice',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: MiraSpacing.pagePadding,
                      vertical: MiraSpacing.base,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: MiraSpacing.md),
                        child: MessageBubble(message: messages[index]),
                      );
                    },
                  ),
          ),

          // Input bar
          _buildInputBar(context, isStreaming),
        ],
      ),
    );
  }

  /// Empty state with suggestion chips.
  /// Ref: PLAN.md Section 3.3 (Chat Suggestion Chips)
  Widget _buildEmptyState(BuildContext context) {
    final coach = _coach;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MiraSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coach != null)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: coach.color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(coach.icon, color: coach.color, size: 28),
              ),
            const SizedBox(height: MiraSpacing.lg),
            Text(
              'Start a conversation',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: MiraSpacing.sm),
            Text(
              'What\'s on your mind today?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MiraColors.textTertiary,
                  ),
            ),
            const SizedBox(height: MiraSpacing.xl),

            // Suggestion chips
            Wrap(
              spacing: MiraSpacing.sm,
              runSpacing: MiraSpacing.sm,
              alignment: WrapAlignment.center,
              children: [
                _buildChip('I need to make a decision'),
                _buildChip('I\'m feeling stuck'),
                _buildChip('I want to set a goal'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String text) {
    return ActionChip(
      label: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MiraColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
      ),
      onPressed: () => _sendMessage(text),
      backgroundColor: MiraColors.surface,
      side: BorderSide(color: MiraColors.divider.withValues(alpha: 0.6), width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MiraRadius.full),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: MiraSpacing.md,
        vertical: MiraSpacing.sm,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// Input bar with text field + send button.
  /// Ref: PLAN.md Section 0.8 (auto-resize, send disabled when empty)
  Widget _buildInputBar(BuildContext context, bool isStreaming) {
    return Container(
      padding: EdgeInsets.only(
        left: MiraSpacing.pagePadding,
        right: MiraSpacing.sm,
        top: MiraSpacing.md,
        bottom: MediaQuery.of(context).viewPadding.bottom + MiraSpacing.md,
      ),
      decoration: BoxDecoration(
        color: MiraColors.surface,
        border: Border(
          top: BorderSide(color: MiraColors.divider.withValues(alpha: 0.5), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text field
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MiraRadius.xl),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MiraRadius.xl),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MiraRadius.xl),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: MiraColors.warmWhite,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MiraSpacing.base,
                  vertical: MiraSpacing.md,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: MiraSpacing.sm),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: isStreaming || _textController.text.trim().isEmpty
                  ? null
                  : () => _sendMessage(_textController.text),
              icon: Icon(
                Icons.arrow_upward,
                color: _textController.text.trim().isEmpty || isStreaming
                    ? MiraColors.textTertiary
                    : Colors.white,
              ),
              style: IconButton.styleFrom(
                backgroundColor:
                    _textController.text.trim().isEmpty || isStreaming
                        ? MiraColors.divider
                        : MiraColors.forestGreen,
                minimumSize: const Size(44, 44),
                shape: const CircleBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
