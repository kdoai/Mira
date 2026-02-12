/// Animated gradient orb — voice session visualizer.
/// Ref: PLAN.md Section 3.3 (Voice Visualizer = animated gradient orb, hero moment)
///
/// Smooth 60fps gradient orb pulsing with speech.
/// Single most impactful visual for the demo video.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'package:mira/theme/app_theme.dart';

class VoiceVisualizer extends StatefulWidget {
  final Color color;
  final bool isActive;

  const VoiceVisualizer({
    super.key,
    required this.color,
    this.isActive = false,
  });

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Pulse animation — gentle breathing effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Rotation for gradient shift
    _rotateController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    );
    _rotateController.repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnimation, _rotateController]),
      builder: (context, _) {
        final scale = _pulseAnimation.value;
        final rotation = _rotateController.value * 2 * pi;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                transform: GradientRotation(rotation),
                colors: [
                  widget.color,
                  widget.color.withValues(alpha: 0.6),
                  MiraColors.gold.withValues(alpha: 0.4),
                  widget.color.withValues(alpha: 0.8),
                  widget.color,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.3),
                  blurRadius: 40 * scale,
                  spreadRadius: 10 * scale,
                ),
                BoxShadow(
                  color: MiraColors.gold.withValues(alpha: 0.15),
                  blurRadius: 60 * scale,
                  spreadRadius: 20 * scale,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
