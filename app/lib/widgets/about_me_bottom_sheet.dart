/// About Me bottom sheet — shown after first sign-in.
/// Ref: PLAN.md Section 3.5 (About Me Onboarding Flow)
///
/// "Help your coach get to know you" — single free-text field, skippable.
/// Max 500 chars.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/providers/chat_provider.dart';
import 'package:mira/theme/app_theme.dart';

class AboutMeBottomSheet extends ConsumerStatefulWidget {
  const AboutMeBottomSheet({super.key});

  @override
  ConsumerState<AboutMeBottomSheet> createState() =>
      _AboutMeBottomSheetState();
}

class _AboutMeBottomSheetState extends ConsumerState<AboutMeBottomSheet> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.updateAboutMe(_controller.text.trim());
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. You can update later from Profile.')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: MiraSpacing.lg,
        right: MiraSpacing.lg,
        top: MiraSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + MiraSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Help your coach\nget to know you',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: MiraSpacing.sm),
          Text(
            'Share a bit about yourself — your goals, challenges, or what you\'re working on. This helps your coach give more relevant advice.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MiraColors.textSecondary,
                ),
          ),
          const SizedBox(height: MiraSpacing.base),

          // Free text field
          TextField(
            controller: _controller,
            maxLength: 500,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText:
                  'e.g. I\'m a 28-year-old software engineer considering a career change. I value work-life balance and creative expression...',
            ),
          ),
          const SizedBox(height: MiraSpacing.base),

          // Save button
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save'),
          ),
          const SizedBox(height: MiraSpacing.sm),

          // Skip
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip for now'),
            ),
          ),
        ],
      ),
    );
  }
}
