/// Coach card widget — clean, flat, Notion-inspired design.
/// Ref: PLAN.md Section 3.3, 3.4, 3.5
///
/// Two variants:
/// - Hero card: full-width, subtle gradient, no shadows
/// - Grid card: half-width, flat surface with subtle border
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mira/models/coach.dart';
import 'package:mira/theme/app_theme.dart';

/// Reusable tap-scale animation wrapper — scale + Material ripple + haptic.
class TapScaleWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  const TapScaleWidget({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius,
  });

  @override
  State<TapScaleWidget> createState() => _TapScaleWidgetState();
}

class _TapScaleWidgetState extends State<TapScaleWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(MiraRadius.xl);
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTapDown: (_) => _ctrl.forward(),
          onTap: () {
            _ctrl.reverse();
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          onTapCancel: () => _ctrl.reverse(),
          borderRadius: radius,
          splashColor: Colors.black.withValues(alpha: 0.06),
          highlightColor: Colors.transparent,
          child: ScaleTransition(scale: _scale, child: widget.child),
        ),
      ),
    );
  }
}

class CoachCard extends StatelessWidget {
  final Coach coach;
  final bool isLarge;
  final VoidCallback onTap;

  const CoachCard({
    super.key,
    required this.coach,
    required this.onTap,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLarge) return _buildHeroCard(context);
    return _buildGridCard(context);
  }

  /// Hero card for General Coach — full width, flat gradient background
  Widget _buildHeroCard(BuildContext context) {
    return TapScaleWidget(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: MiraSpacing.lg,
          vertical: MiraSpacing.lg,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              coach.color,
              coach.color.withValues(alpha: 0.88),
            ],
          ),
          borderRadius: BorderRadius.circular(MiraRadius.xl),
        ),
        child: Row(
          children: [
            // Coach icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(coach.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: MiraSpacing.base),
            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coach.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coach.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: MiraSpacing.sm),
            Icon(
              Icons.arrow_forward,
              color: Colors.white.withValues(alpha: 0.6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Grid card for Pro/Custom coaches — name + focus only, clean and readable
  Widget _buildGridCard(BuildContext context) {
    return TapScaleWidget(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MiraSpacing.base),
        decoration: BoxDecoration(
          color: MiraColors.surface,
          borderRadius: BorderRadius.circular(MiraRadius.lg),
          border: Border.all(
            color: MiraColors.divider,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Coach icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: coach.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(MiraRadius.sm),
                  ),
                  child: Icon(
                    coach.icon,
                    color: coach.color,
                    size: 22,
                  ),
                ),
                const Spacer(),
                // PRO badge
                if (coach.isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MiraSpacing.sm + 2,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: MiraColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(MiraRadius.full),
                    ),
                    child: Text(
                      'PRO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: MiraColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MiraSpacing.md),
            Text(
              coach.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              coach.focus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MiraColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
