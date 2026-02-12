/// Home screen — Coach Library (redesigned with vertical grid).
/// Ref: PLAN.md Section 3.3, 3.4, 3.5
///
/// Layout:
/// - Greeting at top
/// - Follow-up card (if pending action from last session)
/// - General Coach (Mira) hero card with gradient
/// - "Explore Coaches" — 2-column grid of Pro coaches
/// - "Your Coaches" — 2-column grid of custom coaches
/// - "Create Coach" FAB
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mira/models/coach.dart';
import 'package:mira/models/conversation.dart';
import 'package:mira/providers/auth_provider.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/providers/subscription_provider.dart';
import 'package:mira/theme/app_theme.dart';
import 'package:mira/widgets/coach_card.dart';
import 'package:mira/widgets/create_coach_dialog.dart';
import 'package:mira/widgets/about_me_bottom_sheet.dart';
import 'package:mira/widgets/paywall_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isFirst = ref.read(isFirstSignInProvider);
      if (isFirst) {
        ref.read(isFirstSignInProvider.notifier).state = false;
        _showAboutMePrompt();
      }
    });
  }

  void _showAboutMePrompt() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const AboutMeBottomSheet(),
    );
  }

  void _onCoachTap(Coach coach) {
    final isPro = ref.read(isProProvider);
    if (coach.isPro && !isPro) {
      _showPaywall();
      return;
    }
    _showSessionTypeDialog(coach);
  }

  void _showSessionTypeDialog(Coach coach) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(MiraSpacing.base),
          decoration: BoxDecoration(
            color: MiraColors.surface,
            borderRadius: BorderRadius.circular(MiraRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(MiraSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Start a session with ${coach.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: MiraSpacing.lg),
                // Chat option
                _buildSessionOption(
                  context,
                  icon: Icons.chat_bubble_outline,
                  title: 'Text Chat',
                  subtitle: 'Type your thoughts',
                  color: MiraColors.forestGreen,
                  onTap: () {
                    Navigator.pop(context);
                    this.context.push('/chat/${coach.id}');
                  },
                ),
                const SizedBox(height: MiraSpacing.md),
                // Voice option
                _buildSessionOption(
                  context,
                  icon: Icons.mic,
                  title: 'Voice Session',
                  subtitle: ref.read(isProProvider)
                      ? '60 min/month · up to 30-min sessions'
                      : 'One free 5-minute session',
                  color: MiraColors.warmEarth,
                  onTap: () {
                    Navigator.pop(context);
                    this.context.push('/voice/${coach.id}');
                  },
                ),
                const SizedBox(height: MiraSpacing.base),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MiraRadius.lg),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MiraSpacing.base),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(MiraRadius.lg),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: MiraSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MiraColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  void _showPaywall() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PaywallSheet(),
    );
  }

  void _showCoachActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(MiraSpacing.base),
        decoration: BoxDecoration(
          color: MiraColors.surface,
          borderRadius: BorderRadius.circular(MiraRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(MiraSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSessionOption(
                ctx,
                icon: Icons.add_circle_outline,
                title: 'Create a Coach',
                subtitle: 'Build your own custom AI coach',
                color: MiraColors.forestGreen,
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (context) => const CreateCoachDialog(),
                  );
                },
              ),
              const SizedBox(height: MiraSpacing.md),
              _buildSessionOption(
                ctx,
                icon: Icons.person_add_outlined,
                title: 'Add Shared Coach',
                subtitle: 'Enter an 8-character share code',
                color: MiraColors.warmEarth,
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddCoachDialog();
                },
              ),
              const SizedBox(height: MiraSpacing.base),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCoachDialog() {
    final codeController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MiraRadius.xl),
          ),
          title: const Text('Add Shared Coach'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the 8-character share code to add a coach created by someone else.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: MiraColors.textSecondary,
                    ),
              ),
              const SizedBox(height: MiraSpacing.base),
              TextField(
                controller: codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Share code',
                  hintText: 'e.g. AB12CD34',
                ),
                maxLength: 8,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final code = codeController.text.trim().toUpperCase();
                      if (code.length != 8) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a full 8-character code')),
                        );
                        return;
                      }
                      setDialogState(() => isLoading = true);
                      try {
                        final api = ref.read(apiServiceProvider);
                        await api.addSharedCoach(code);
                        await ref.read(coachesProvider.notifier).loadCustomCoaches(api);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coach added to your library!')),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() => isLoading = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(e.toString().contains('404') ? 'Coach not found' : 'Failed to add coach')),
                          );
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final coaches = ref.watch(coachesProvider);
    final followUp = ref.watch(pendingFollowUpProvider);
    final userName =
        authState.valueOrNull?.displayName?.split(' ').first ?? '';

    final generalCoach = coaches.firstWhere((c) => c.id == 'mira');
    final proCoaches =
        coaches.where((c) => c.isPro && c.isBuiltIn).toList();
    final customCoaches = coaches.where((c) => !c.isBuiltIn).toList();

    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(conversationsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: MiraSpacing.pagePadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: MiraSpacing.xl),

                // Greeting
                Text(
                  '${_getGreeting()}${userName.isNotEmpty ? ', $userName' : ''}',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: MiraSpacing.xs),
                Text(
                  'What would you like to work on today?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: MiraColors.textTertiary,
                      ),
                ),
                const SizedBox(height: MiraSpacing.lg),

                // General Coach — hero card (primary CTA, always first)
                CoachCard(
                  coach: generalCoach,
                  isLarge: true,
                  onTap: () => _onCoachTap(generalCoach),
                ),
                const SizedBox(height: MiraSpacing.lg),

                // Follow-up card — gentle action item reminder
                if (followUp.valueOrNull != null)
                  _buildFollowUpCard(context, followUp.valueOrNull!),

                // Quick Start — intent-based coaching entry
                _buildQuickStart(coaches),
                const SizedBox(height: MiraSpacing.xl),

                // Visual separator
                Divider(height: 1, color: MiraColors.divider.withValues(alpha: 0.5)),
                const SizedBox(height: MiraSpacing.lg),

                // Pro Coaches — 2-column grid
                Text(
                  'Explore Coaches',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                ),
                const SizedBox(height: MiraSpacing.base),
                _buildCoachGrid(proCoaches),

                // Custom Coaches section
                if (customCoaches.isNotEmpty) ...[
                  const SizedBox(height: MiraSpacing.xxl),
                  Text(
                    'Your Coaches',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const SizedBox(height: MiraSpacing.base),
                  _buildCoachGrid(customCoaches),
                ],

                // Create Coach inline button (replaces FAB)
                const SizedBox(height: MiraSpacing.lg),
                _buildCreateCoachButton(),

                const SizedBox(height: MiraSpacing.xl),
              ],
            ),
          ),
        ),
      ),

    );
  }

  /// Follow-up card — Notion-style left-border callout.
  /// Shows the latest pending action item from a previous session.
  Widget _buildFollowUpCard(BuildContext context, Conversation conv) {
    final coach = ref.read(coachesProvider.notifier).getCoach(conv.coachId);
    final coachColor = coach?.color ?? MiraColors.forestGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: MiraSpacing.lg),
      child: GestureDetector(
        onTap: () => context.push('/chat/${conv.coachId}?conversationId=${conv.id}'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MiraSpacing.base),
          decoration: BoxDecoration(
            color: MiraColors.surface,
            border: Border(
              left: BorderSide(color: coachColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.replay_outlined,
                    size: 16,
                    color: MiraColors.textTertiary,
                  ),
                  const SizedBox(width: MiraSpacing.sm),
                  Text(
                    'Continue with ${coach?.name ?? conv.coachName}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: MiraColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: MiraSpacing.sm),
              Text(
                conv.nextAction,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: MiraSpacing.md),
              Text(
                'Check in \u2192',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: coachColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick Start — intent-based coaching entry chips.
  /// Ref: Notion-like minimal pill chips, wrap layout.
  static const _quickStartIntents = [
    ('Make a decision', 'mira'),
    ('Overcome a block', 'atlas'),
    ('Manage stress', 'sol'),
    ('Hard conversation', 'ember'),
  ];

  Widget _buildQuickStart(List<Coach> coaches) {
    // 2×2 grid with uniform chip sizes
    final items = _quickStartIntents.map((item) {
      final coach = coaches.firstWhere(
        (c) => c.id == item.$2,
        orElse: () => coaches.first,
      );
      return (item.$1, coach);
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildIntentChip(items[0].$1, items[0].$2)),
            const SizedBox(width: MiraSpacing.sm),
            Expanded(child: _buildIntentChip(items[1].$1, items[1].$2)),
          ],
        ),
        const SizedBox(height: MiraSpacing.sm),
        Row(
          children: [
            Expanded(child: _buildIntentChip(items[2].$1, items[2].$2)),
            const SizedBox(width: MiraSpacing.sm),
            Expanded(child: _buildIntentChip(items[3].$1, items[3].$2)),
          ],
        ),
      ],
    );
  }

  Widget _buildIntentChip(String label, Coach coach) {
    return TapScaleWidget(
      onTap: () => _onCoachTap(coach),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MiraSpacing.md,
          vertical: MiraSpacing.sm + 2,
        ),
        decoration: BoxDecoration(
          color: MiraColors.surface,
          borderRadius: BorderRadius.circular(MiraRadius.full),
          border: Border.all(color: MiraColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: coach.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: MiraSpacing.sm),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Inline "Create Coach" button — replaces FAB to avoid overlap
  Widget _buildCreateCoachButton() {
    return TapScaleWidget(
      onTap: () {
        final isPro = ref.read(isProProvider);
        if (!isPro) {
          _showPaywall();
          return;
        }
        _showCoachActions();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: MiraSpacing.base,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MiraRadius.lg),
          border: Border.all(
            color: MiraColors.forestGreen.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: MiraColors.forestGreen, size: 20),
            const SizedBox(width: MiraSpacing.sm),
            Text(
              'Create or Add a Coach',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: MiraColors.forestGreen,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a 2-column grid of coach cards
  Widget _buildCoachGrid(List<Coach> coaches) {
    final List<Widget> rows = [];
    for (int i = 0; i < coaches.length; i += 2) {
      final first = coaches[i];
      final second = (i + 1 < coaches.length) ? coaches[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 < coaches.length ? MiraSpacing.md : 0,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: CoachCard(
                    coach: first,
                    onTap: () => _onCoachTap(first),
                  ),
                ),
                const SizedBox(width: MiraSpacing.md),
                Expanded(
                  child: second != null
                      ? CoachCard(
                          coach: second,
                          onTap: () => _onCoachTap(second),
                        )
                      : const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

