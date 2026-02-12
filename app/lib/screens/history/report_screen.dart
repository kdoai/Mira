/// Session report screen — Notion-like layout with conversation history.
/// Ref: PLAN.md Section 8.6 (Session Report), Section 3.3 (Notion-like reports)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mira/models/conversation.dart';
import 'package:mira/models/message.dart';
import 'package:mira/models/session_report.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/services/api_service.dart';
import 'package:mira/theme/app_theme.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String? coachId;

  const ReportScreen({
    super.key,
    required this.conversationId,
    this.coachId,
  });

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  SessionReport? _report;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _conversationExpanded = false;
  bool _actionCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final results = await Future.wait([
        apiService.generateReport(widget.conversationId),
        apiService.getMessages(widget.conversationId, limit: 100),
      ]);
      final rawMessages = results[1] as List<ChatMessage>;
      // Consolidate adjacent same-role messages (fixes old fragmented voice transcripts)
      final consolidated = <ChatMessage>[];
      for (final msg in rawMessages) {
        if (consolidated.isNotEmpty && consolidated.last.role == msg.role) {
          final prev = consolidated.last;
          consolidated[consolidated.length - 1] = prev.copyWith(
            content: prev.content + msg.content,
          );
        } else {
          consolidated.add(msg);
        }
      }
      setState(() {
        _report = results[0] as SessionReport;
        _messages = consolidated;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.statusCode == 400
            ? 'This session needs a few more messages before a report can be generated.'
            : 'Could not generate report. Please try again.';
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not generate report. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/history'),
        ),
        title: const Text('Session Report'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: MiraColors.textTertiary,
              ),
            )
          : _error != null
              ? _buildError(context)
              : _buildReport(context),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: MiraColors.textTertiary),
          const SizedBox(height: MiraSpacing.base),
          Text(_error!, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: MiraSpacing.base),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildReport(BuildContext context) {
    final report = _report!;
    final theme = Theme.of(context).textTheme;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final d = report.generatedAt;
    final formattedDate = '${months[d.month - 1]} ${d.day}, ${d.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(MiraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Header --
          Center(
            child: Text(
              'Session Report',
              style: theme.headlineSmall,
            ),
          ),
          const SizedBox(height: MiraSpacing.xs),
          Center(
            child: Text(
              'Generated on $formattedDate',
              style: theme.labelSmall?.copyWith(
                color: MiraColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: MiraSpacing.base),
          const Divider(),
          const SizedBox(height: MiraSpacing.lg),

          // -- Next Action (hero) --
          _buildNextAction(context),

          // -- Summary --
          _buildSectionHeader(context, 'Summary', Icons.description_outlined),
          const SizedBox(height: MiraSpacing.md),
          Text(
            report.summary,
            style: theme.bodyLarge?.copyWith(height: 1.6),
          ),
          const SizedBox(height: MiraSpacing.lg),

          // -- Key Insights --
          _buildSectionHeader(context, 'Key Insights', Icons.lightbulb_outline),
          const SizedBox(height: MiraSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MiraSpacing.base),
            decoration: BoxDecoration(
              color: MiraColors.warmEarth.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(MiraRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: report.keyInsights.map((insight) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: MiraSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u2192  ',
                        style: theme.bodyMedium?.copyWith(
                          color: MiraColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          insight,
                          style: theme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: MiraSpacing.lg),

          // -- Action Items --
          _buildSectionHeader(
              context, 'Action Items', Icons.check_circle_outline),
          const SizedBox(height: MiraSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: report.actionItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: MiraSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.radio_button_unchecked,
                      size: 16,
                      color: MiraColors.textSecondary,
                    ),
                    const SizedBox(width: MiraSpacing.sm),
                    Expanded(
                      child: Text(
                        item,
                        style: theme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: MiraSpacing.lg),

          // -- Mood Observation --
          _buildSectionHeader(context, 'Mood Observation', Icons.mood_outlined),
          const SizedBox(height: MiraSpacing.md),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: MiraColors.warmEarth,
                  width: 3,
                ),
              ),
            ),
            padding: const EdgeInsets.only(left: MiraSpacing.base),
            child: Text(
              report.moodObservation,
              style: theme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: MiraColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: MiraSpacing.lg),

          // -- Conversation History (collapsible) --
          if (_messages.isNotEmpty) ...[
            _buildConversationSection(context),
            const SizedBox(height: MiraSpacing.lg),
          ],

          // -- Continue Session Button --
          if (widget.coachId != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push(
                    '/chat/${widget.coachId}?conversationId=${widget.conversationId}',
                  );
                },
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Continue Session'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MiraColors.forestGreen,
                  side: const BorderSide(color: MiraColors.forestGreen),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MiraRadius.md),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MiraSpacing.lg),
          ],

          // -- Footer --
          Center(
            child: Text(
              'Generated by Mira',
              style: theme.labelSmall?.copyWith(
                color: MiraColors.textTertiary,
              ),
            ),
          ),
          const SizedBox(height: MiraSpacing.base),
        ],
      ),
    );
  }

  Widget _buildNextAction(BuildContext context) {
    // Show completed state if just marked done
    if (_actionCompleted) {
      return Padding(
        padding: const EdgeInsets.only(bottom: MiraSpacing.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MiraSpacing.base),
          decoration: BoxDecoration(
            color: MiraColors.forestGreen.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(MiraRadius.md),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 20,
                color: MiraColors.forestGreen.withValues(alpha: 0.6),
              ),
              const SizedBox(width: MiraSpacing.md),
              Text(
                'Action completed!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MiraColors.forestGreen,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Look up conversation from already-loaded provider
    final conversationsAsync = ref.watch(conversationsProvider);
    Conversation? conversation;
    for (final c in conversationsAsync.valueOrNull ?? <Conversation>[]) {
      if (c.id == widget.conversationId) {
        conversation = c;
        break;
      }
    }

    // Hide if no conversation, no action, or already done
    if (conversation == null ||
        conversation.nextAction.isEmpty ||
        conversation.actionStatus == 'done') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: MiraSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, 'Your Next Step', Icons.flag_outlined),
          const SizedBox(height: MiraSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MiraSpacing.base),
            decoration: BoxDecoration(
              border: const Border(
                left: BorderSide(color: MiraColors.forestGreen, width: 3),
              ),
              color: Colors.white,
              borderRadius: BorderRadius.circular(MiraRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.nextAction,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: MiraSpacing.md),
                GestureDetector(
                  onTap: () async {
                    try {
                      final apiService = ref.read(apiServiceProvider);
                      await apiService.updateActionStatus(
                        conversationId: widget.conversationId,
                        actionStatus: 'done',
                      );
                      ref.invalidate(conversationsProvider);
                      if (mounted) {
                        setState(() => _actionCompleted = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nice work! Action completed.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (_) {}
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_box_outline_blank_rounded,
                        size: 18,
                        color: MiraColors.forestGreen,
                      ),
                      const SizedBox(width: MiraSpacing.sm),
                      Text(
                        'Mark as done',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: MiraColors.forestGreen,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationSection(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Collapsible header
        GestureDetector(
          onTap: () => setState(() {
            _conversationExpanded = !_conversationExpanded;
          }),
          child: Row(
            children: [
              Icon(
                _conversationExpanded
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 20,
                color: MiraColors.textTertiary,
              ),
              const SizedBox(width: MiraSpacing.sm),
              Text(
                'Conversation',
                style: theme.labelMedium?.copyWith(
                  color: MiraColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: MiraSpacing.sm),
              Text(
                '${_messages.length} messages',
                style: theme.labelSmall?.copyWith(
                  color: MiraColors.textTertiary,
                ),
              ),
            ],
          ),
        ),

        // Expanded conversation
        if (_conversationExpanded) ...[
          const SizedBox(height: MiraSpacing.md),
          Container(
            padding: const EdgeInsets.all(MiraSpacing.base),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(MiraRadius.md),
              border: Border.all(
                color: MiraColors.textTertiary.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: _messages.map((msg) {
                final isUser = msg.role == 'user';
                return Padding(
                  padding: const EdgeInsets.only(bottom: MiraSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isUser
                              ? MiraColors.forestGreen.withValues(alpha: 0.1)
                              : MiraColors.warmEarth.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isUser ? Icons.person : Icons.auto_awesome,
                          size: 13,
                          color: isUser
                              ? MiraColors.forestGreen
                              : MiraColors.warmEarth,
                        ),
                      ),
                      const SizedBox(width: MiraSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isUser ? 'You' : 'Coach',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: MiraColors.textTertiary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              msg.content,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: MiraColors.textSecondary),
        const SizedBox(width: MiraSpacing.sm),
        Text(title, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}
