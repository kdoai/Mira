/// Profile screen — includes settings (merged, no separate settings screen).
/// Ref: PLAN.md Section 3.3, 7 (Profile tab includes sign-out, About Me link)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mira/providers/auth_provider.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/providers/subscription_provider.dart';
import 'package:mira/theme/app_theme.dart';
import 'package:mira/widgets/paywall_sheet.dart';

const _baseUrl = 'https://mira-backend-796818796548.us-central1.run.app';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final isPro = ref.watch(isProProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: MiraSpacing.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: MiraSpacing.lg),
              Text(
                'Profile',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: MiraSpacing.lg),

              // User info — clean, no card wrapper (Notion-like)
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: MiraColors.forestGreen,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            (user?.displayName ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: MiraSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user?.displayName ?? 'User',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Pro badge
                            if (isPro) ...[
                              const SizedBox(width: MiraSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: MiraSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MiraColors.gold,
                                  borderRadius:
                                      BorderRadius.circular(MiraRadius.full),
                                ),
                                child: Text(
                                  'PRO',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: MiraSpacing.xs),
                        Text(
                          user?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MiraSpacing.lg),

              // Usage summary
              _buildUsageSummary(context, ref, isPro),

              const Divider(),
              const SizedBox(height: MiraSpacing.sm),

              // Menu items
              _buildMenuItem(
                context,
                icon: Icons.edit_outlined,
                title: 'Edit Name',
                subtitle: user?.displayName ?? 'Set your display name',
                onTap: () => _showEditNameDialog(context, ref, user?.displayName ?? ''),
              ),
              _buildMenuItem(
                context,
                icon: Icons.person_outline,
                title: 'About Me',
                subtitle: 'Help your coach get to know you',
                onTap: () => context.push('/about-me'),
              ),
              _buildMenuItem(
                context,
                icon: Icons.workspace_premium_outlined,
                title: isPro ? 'Manage Subscription' : 'Upgrade to Pro',
                subtitle: isPro
                    ? 'View your Pro subscription'
                    : 'Unlock all coaches, voice, and more',
                onTap: () {
                  if (isPro) {
                    launchUrl(Uri.parse('$_baseUrl/manage-subscription'),
                        mode: LaunchMode.externalApplication);
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (context) => const PaywallSheet(),
                    );
                  }
                },
              ),
              _buildMenuItem(
                context,
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help with Mira',
                onTap: () => launchUrl(Uri.parse('$_baseUrl/support'),
                    mode: LaunchMode.externalApplication),
              ),
              _buildMenuItem(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () => launchUrl(Uri.parse('$_baseUrl/privacy'),
                    mode: LaunchMode.externalApplication),
              ),
              const Divider(height: MiraSpacing.xl),
              _buildMenuItem(
                context,
                icon: Icons.logout,
                title: 'Sign Out',
                subtitle: '',
                isDestructive: true,
                onTap: () async {
                  final authService = ref.read(authServiceProvider);
                  final rc = ref.read(revenueCatServiceProvider);
                  await rc.logOut();
                  await authService.signOut();
                  // Clear all user-specific cached data
                  ref.invalidate(conversationsProvider);
                  ref.invalidate(userProfileProvider);
                  ref.invalidate(coachesProvider);
                  ref.invalidate(isProProvider);
                  if (context.mounted) context.go('/onboarding');
                },
              ),
              const SizedBox(height: MiraSpacing.xl),

              // App version
              Center(
                child: Text(
                  'Mira v1.0.0',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: MiraSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUsageSummary(BuildContext context, WidgetRef ref, bool isPro) {
    final profile = ref.watch(userProfileProvider);
    return profile.when(
      data: (p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: MiraSpacing.lg),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(MiraSpacing.base),
            decoration: BoxDecoration(
              color: MiraColors.surface,
              borderRadius: BorderRadius.circular(MiraRadius.lg),
              border: Border.all(color: MiraColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usage',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: MiraSpacing.md),
                // Messages
                _buildUsageRow(
                  context,
                  icon: Icons.chat_bubble_outline,
                  label: 'Messages today',
                  value: isPro
                      ? 'Unlimited'
                      : '${p.dailyMessagesUsed} / ${p.dailyMessagesLimit}',
                ),
                const SizedBox(height: MiraSpacing.sm),
                // Voice
                _buildUsageRow(
                  context,
                  icon: Icons.mic_none,
                  label: 'Voice this month',
                  value: isPro
                      ? '${p.voiceMinutesUsed.round()} / ${p.voiceMinutesLimit} min'
                      : 'Free trial (5 min × 1)',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildUsageRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MiraColors.textTertiary),
        const SizedBox(width: MiraSpacing.sm),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  void _showEditNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your name'),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                // Update directly via Firebase Auth client SDK (no server permission needed)
                final user = ref.read(authServiceProvider).currentUser;
                await user?.updateDisplayName(name);
                await user?.reload();
                if (context.mounted) {
                  ref.invalidate(authStateProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name updated')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update name')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MiraRadius.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MiraSpacing.base,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? MiraColors.error
                    : MiraColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: MiraSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: isDestructive
                                ? MiraColors.textSecondary
                                : MiraColors.textPrimary,
                          ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isDestructive)
                const Icon(
                  Icons.chevron_right,
                  color: MiraColors.textTertiary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

