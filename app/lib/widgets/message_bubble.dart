/// Chat message bubble widget — Notion-inspired, content-first design.
/// Ref: PLAN.md Section 0.8 (chat message fade-in, auto-scroll)
///
/// User messages: right-aligned, Forest Green background, uniform radius
/// Assistant messages: left-aligned, clean text on warmWhite — no border,
///   resembling a Notion AI block (typography-driven, no bubble decoration)
/// Streaming indicator: animated dots
library;

import 'package:flutter/material.dart';

import 'package:mira/models/message.dart';
import 'package:mira/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  bool get _isUser => message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (_isUser ? 0.78 : 0.88),
        ),
        margin: EdgeInsets.only(
          left: _isUser ? 48 : 0,
          right: _isUser ? 0 : MiraSpacing.lg,
          bottom: MiraSpacing.xs,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: _isUser ? MiraSpacing.base : MiraSpacing.xs,
          vertical: _isUser ? MiraSpacing.base : MiraSpacing.md,
        ),
        decoration: _isUser
            ? BoxDecoration(
                color: MiraColors.forestGreen,
                borderRadius: BorderRadius.circular(MiraRadius.lg),
              )
            : null,
        child: message.content.isEmpty && message.isStreaming
            ? _buildStreamingIndicator()
            : Text(
                message.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isUser ? Colors.white : MiraColors.textPrimary,
                      height: 1.6,
                      letterSpacing: -0.1,
                    ),
              ),
      ),
    );
  }

  Widget _buildStreamingIndicator() {
    return const _DotsIndicator();
  }
}

class _DotsIndicator extends StatefulWidget {
  const _DotsIndicator();

  @override
  State<_DotsIndicator> createState() => _DotsIndicatorState();
}

class _DotsIndicatorState extends State<_DotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (value < 0.5) ? value * 2 : (1.0 - value) * 2;
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: MiraColors.textTertiary
                    .withValues(alpha: 0.3 + opacity * 0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
