/// Journal screen — Notion-like personal productivity journal.
/// Ref: PLAN.md Section 7.1 (bottom nav tab 2)
///
/// 2-section design:
/// 1. Active Actions — up to 3 pending action items with checkboxes
/// 2. Sessions — time-grouped (Today / This Week / Earlier) with report transition
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mira/models/conversation.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/theme/app_theme.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final Set<String> _completingIds = {};
  final Set<String> _deletedIds = {};
  final Map<String, Timer> _deleteTimers = {};

  @override
  void dispose() {
    // Fire all pending deletes immediately on dispose
    for (final entry in _deleteTimers.entries) {
      entry.value.cancel();
      _deleteConversation(entry.key);
    }
    _deleteTimers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      body: SafeArea(
        child: conversations.when(
          data: (list) {
            final filtered =
                list.where((c) => !_deletedIds.contains(c.id)).toList();
            if (filtered.isEmpty) return _buildEmptyState(context);
            return RefreshIndicator(
              onRefresh: () async {
                _completingIds.clear();
                // NOTE: Do NOT clear _deletedIds — keeps deleted items hidden
                // even if Firestore hasn't fully propagated yet.
                ref.invalidate(conversationsProvider);
              },
              child: _buildJournal(context, filtered),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: MiraColors.textTertiary),
          ),
          error: (_, __) => _buildErrorState(context),
        ),
      ),
    );
  }

  Widget _buildJournal(BuildContext context, List<Conversation> list) {
    // Active actions: pending actions not yet completed (max 3)
    final actions = list
        .where((c) =>
            c.nextAction.isNotEmpty &&
            c.actionStatus != 'done' &&
            !_completingIds.contains(c.id))
        .take(3)
        .toList();

    // Time-grouped sessions
    final groups = _groupByTime(list);

    return ListView(
      padding:
          const EdgeInsets.symmetric(horizontal: MiraSpacing.pagePadding),
      children: [
        const SizedBox(height: MiraSpacing.lg),
        Text('Journal', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: MiraSpacing.xl),

        // Active Actions section
        _buildActiveActions(context, actions),
        const SizedBox(height: MiraSpacing.xxl),

        // Time-grouped sessions
        for (final entry in groups.entries)
          if (entry.value.isNotEmpty) ...[
            _buildSectionLabel(context, entry.key),
            ...entry.value.map((c) => _buildDismissible(context, c)),
            const SizedBox(height: MiraSpacing.lg),
          ],

        const SizedBox(height: MiraSpacing.xl),
      ],
    );
  }

  // ── Active Actions ──

  Widget _buildActiveActions(
      BuildContext context, List<Conversation> actions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(context, 'ACTIVE ACTIONS'),
        if (actions.isEmpty)
          _buildAllCaughtUp(context)
        else
          ...actions.map((c) => _buildActionRow(context, c)),
      ],
    );
  }

  Widget _buildAllCaughtUp(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MiraSpacing.base),
      decoration: BoxDecoration(
        color: MiraColors.textTertiary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(MiraRadius.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 20,
            color: MiraColors.textTertiary,
          ),
          const SizedBox(width: MiraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All caught up',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete a session to get your next action.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: MiraColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, Conversation conv) {
    final coach = ref.read(coachesProvider.notifier).getCoach(conv.coachId);
    final coachColor = coach?.color ?? MiraColors.forestGreen;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: MiraSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => _completeAction(conv),
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: MiraSpacing.md),
                  child: Icon(
                    Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: MiraColors.forestGreen,
                  ),
                ),
              ),
              // Action text + metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conv.nextAction,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          conv.coachName,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: coachColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                        Text(
                          '  ·  ${_formatTime(conv.updatedAt)}',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: MiraColors.textTertiary,
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: MiraColors.divider),
      ],
    );
  }

  Future<void> _completeAction(Conversation conv) async {
    setState(() => _completingIds.add(conv.id));
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.updateActionStatus(
        conversationId: conv.id,
        actionStatus: 'done',
      );
      ref.invalidate(conversationsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nice work! Action completed.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _completingIds.remove(conv.id));
    }
  }

  // ── Time Grouping ──

  Map<String, List<Conversation>> _groupByTime(List<Conversation> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    final groups = <String, List<Conversation>>{
      'TODAY': [],
      'THIS WEEK': [],
      'EARLIER': [],
    };

    for (final c in list) {
      final local = c.updatedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      if (!date.isBefore(today)) {
        groups['TODAY']!.add(c);
      } else if (!date.isBefore(weekStart)) {
        groups['THIS WEEK']!.add(c);
      } else {
        groups['EARLIER']!.add(c);
      }
    }

    return groups;
  }

  // ── Session Row ──

  Widget _buildSessionRow(BuildContext context, Conversation conv) {
    final coach = ref.read(coachesProvider.notifier).getCoach(conv.coachId);
    final coachColor = coach?.color ?? MiraColors.forestGreen;

    // Unified tap: report if enough content, otherwise resume chat
    final goToReport = conv.hasReport || conv.messageCount >= 4;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (goToReport) {
              context.push('/report/${conv.id}?coachId=${conv.coachId}');
            } else if (conv.type == 'voice') {
              // Resume voice sessions in voice mode
              context.push('/voice/${conv.coachId}');
            } else {
              context.push('/chat/${conv.coachId}?conversationId=${conv.id}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conv.displayTitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Preview line (separate from title)
                      if (conv.lastMessagePreview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          conv.lastMessagePreview,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: MiraColors.textTertiary,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (conv.type == 'voice') ...[
                            Icon(Icons.mic, size: 12, color: coachColor),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            conv.coachName,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: coachColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                          ),
                          Text(
                            '  ·  ${_formatTime(conv.updatedAt)}',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: MiraColors.textTertiary,
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: MiraColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: MiraColors.divider),
      ],
    );
  }

  // ── Swipe-to-delete ──

  Widget _buildDismissible(BuildContext context, Conversation conv) {
    return Dismissible(
      key: ValueKey(conv.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        setState(() => _deletedIds.add(conv.id));
        _showUndoSnackBar(conv);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(MiraRadius.md),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade400),
      ),
      child: _buildSessionRow(context, conv),
    );
  }

  void _showUndoSnackBar(Conversation conv) {
    // Cancel any existing timer for this item
    _deleteTimers[conv.id]?.cancel();

    // Start a timer — delete fires after 4 seconds regardless of SnackBar
    _deleteTimers[conv.id] = Timer(const Duration(seconds: 4), () {
      _deleteTimers.remove(conv.id);
      _deleteConversation(conv.id);
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Session deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: MiraColors.gold,
          onPressed: () {
            _deleteTimers[conv.id]?.cancel();
            _deleteTimers.remove(conv.id);
            setState(() => _deletedIds.remove(conv.id));
            ref.invalidate(conversationsProvider);
          },
        ),
      ),
    );
  }

  Future<void> _deleteConversation(String id) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.deleteConversation(id);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete session.')),
        );
        setState(() => _deletedIds.remove(id));
      }
    }
  }

  // ── Shared ──

  Widget _buildSectionLabel(BuildContext context, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: MiraColors.textTertiary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, color: MiraColors.divider),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 64,
            color: MiraColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: MiraSpacing.base),
          Text(
            'Your journal is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: MiraColors.textSecondary,
                ),
          ),
          const SizedBox(height: MiraSpacing.sm),
          Text(
            'Start a session with a coach to see\nyour actions and sessions here.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MiraColors.textTertiary,
                ),
          ),
          const SizedBox(height: MiraSpacing.lg),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 48),
            ),
            child: const Text('Start a Session'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: MiraColors.textTertiary,
          ),
          const SizedBox(height: MiraSpacing.base),
          Text(
            'Could not load journal',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: MiraColors.textSecondary,
                ),
          ),
          const SizedBox(height: MiraSpacing.base),
          ElevatedButton(
            onPressed: () => ref.invalidate(conversationsProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
