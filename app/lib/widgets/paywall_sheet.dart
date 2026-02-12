/// Shared paywall bottom sheet — used by Home and Profile screens.
/// Ref: PLAN.md Section 3.2 (Pricing), Section 3.3 (Bottom-sheet paywall)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/providers/subscription_provider.dart';
import 'package:mira/theme/app_theme.dart';

class PaywallSheet extends ConsumerStatefulWidget {
  const PaywallSheet({super.key});

  @override
  ConsumerState<PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends ConsumerState<PaywallSheet> {
  bool _isPurchasing = false;
  bool _isRestoring = false;
  bool _isAnnual = false;

  Future<void> _purchase() async {
    setState(() => _isPurchasing = true);
    try {
      final rc = ref.read(revenueCatServiceProvider);
      final offerings = await rc.getOfferings();
      final package = _isAnnual
          ? offerings?.current?.annual
          : offerings?.current?.monthly;
      if (package == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No offerings available yet.')),
          );
        }
        return;
      }
      final success = await ref.read(isProProvider.notifier).purchase(package);
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to Mira Pro!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() => _isRestoring = true);
    try {
      final success = await ref.read(isProProvider.notifier).restore();
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchases restored!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previous purchases found.')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: MiraColors.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(MiraRadius.xl),
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(MiraSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MiraColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: MiraSpacing.lg),
                Text(
                  'Unlock Your Full Potential',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MiraSpacing.sm),
                Text(
                  'Get the most out of Mira with Pro',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: MiraColors.textSecondary,
                      ),
                ),
                const SizedBox(height: MiraSpacing.xl),
                _buildFeature(context, Icons.people_outline,
                    'All 5 AI coaches', 'Career, Creativity, Wellness, Relationships + General'),
                _buildFeature(context, Icons.mic_none,
                    'Voice coaching', '60 min/month · up to 30-min sessions'),
                _buildFeature(context, Icons.all_inclusive,
                    'Unlimited messages', 'No daily limits (free: 10/day)'),
                _buildFeature(context, Icons.auto_awesome_outlined,
                    'Create custom coaches', 'Build and share your own coaches'),
                _buildFeature(context, Icons.description_outlined,
                    'Session reports', 'AI-generated insights and action items'),
                const SizedBox(height: MiraSpacing.xl),

                // Plan selection
                _buildPlanOption(
                  context,
                  title: '\$9.99/month',
                  subtitle: '7-day free trial',
                  isSelected: !_isAnnual,
                  onTap: () => setState(() => _isAnnual = false),
                ),
                const SizedBox(height: MiraSpacing.md),
                _buildPlanOption(
                  context,
                  title: '\$79.99/year',
                  subtitle: 'Save 33% — just \$6.67/month',
                  badge: 'BEST VALUE',
                  isSelected: _isAnnual,
                  onTap: () => setState(() => _isAnnual = true),
                ),

                const SizedBox(height: MiraSpacing.lg),
                ElevatedButton(
                  onPressed: _isPurchasing ? null : _purchase,
                  child: _isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isAnnual ? 'Subscribe Yearly' : 'Start Free Trial'),
                ),
                const SizedBox(height: MiraSpacing.sm),
                TextButton(
                  onPressed: _isRestoring ? null : _restore,
                  child: _isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Restore Purchases'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MiraSpacing.base),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? MiraColors.forestGreen : MiraColors.divider,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(MiraRadius.lg),
          color: isSelected
              ? MiraColors.forestGreen.withValues(alpha: 0.04)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? MiraColors.forestGreen
                      : MiraColors.textTertiary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: MiraColors.forestGreen,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: MiraSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MiraColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MiraSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: MiraColors.gold,
                  borderRadius: BorderRadius.circular(MiraRadius.full),
                ),
                child: Text(
                  badge,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 9,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeature(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MiraSpacing.base),
      child: Row(
        children: [
          Icon(icon, color: MiraColors.forestGreen, size: 24),
          const SizedBox(width: MiraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
