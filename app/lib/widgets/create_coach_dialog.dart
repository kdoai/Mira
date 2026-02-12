/// Create Coach dialog — simple form: Name + Focus + Style.
/// Ref: PLAN.md Section 3.5, 8.4 (Custom Coach Creation)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mira/models/coach.dart';
import 'package:mira/providers/chat_provider.dart';
import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/theme/app_theme.dart';

class CreateCoachDialog extends ConsumerStatefulWidget {
  const CreateCoachDialog({super.key});

  @override
  ConsumerState<CreateCoachDialog> createState() => _CreateCoachDialogState();
}

class _CreateCoachDialogState extends ConsumerState<CreateCoachDialog> {
  final _nameController = TextEditingController();
  final _focusController = TextEditingController();
  String _style = 'warm';
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _focusController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nameController.text.trim().length >= 2 &&
      _focusController.text.trim().length >= 10;

  Future<void> _create() async {
    if (!_isValid || _isCreating) return;
    setState(() => _isCreating = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.createCoach(
        name: _nameController.text.trim(),
        focus: _focusController.text.trim(),
        style: _style,
      );

      final coach = Coach.fromJson(result);
      ref.read(coachesProvider.notifier).addCoach(coach);

      if (mounted) {
        Navigator.pop(context);
        _showShareCodeSheet(context, coach);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create coach. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showShareCodeSheet(BuildContext ctx, Coach coach) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        margin: const EdgeInsets.all(MiraSpacing.base),
        padding: const EdgeInsets.all(MiraSpacing.lg),
        decoration: BoxDecoration(
          color: MiraColors.surface,
          borderRadius: BorderRadius.circular(MiraRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: MiraColors.forestGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: MiraColors.forestGreen, size: 28),
            ),
            const SizedBox(height: MiraSpacing.base),
            Text(
              '${coach.name} is ready!',
              style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: MiraSpacing.sm),
            Text(
              'Share this code so others can add your coach:',
              style: Theme.of(sheetCtx).textTheme.bodyMedium?.copyWith(
                    color: MiraColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MiraSpacing.lg),
            // Share code display
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MiraSpacing.lg,
                vertical: MiraSpacing.base,
              ),
              decoration: BoxDecoration(
                color: MiraColors.warmWhite,
                borderRadius: BorderRadius.circular(MiraRadius.md),
                border: Border.all(color: MiraColors.divider),
              ),
              child: Text(
                coach.shareCode,
                style: Theme.of(sheetCtx).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                    ),
              ),
            ),
            const SizedBox(height: MiraSpacing.lg),
            // Copy button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: coach.shareCode));
                  ScaffoldMessenger.of(sheetCtx).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy Code'),
              ),
            ),
            const SizedBox(height: MiraSpacing.sm),
            TextButton(
              onPressed: () => Navigator.pop(sheetCtx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MiraRadius.xl),
      ),
      title: const Text('Create a Coach'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Coach name',
                hintText: 'e.g. Luna',
              ),
              maxLength: 30,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MiraSpacing.base),

            // Focus
            TextField(
              controller: _focusController,
              decoration: const InputDecoration(
                labelText: 'What should this coach help with?',
                hintText: 'e.g. Public speaking and presentation skills',
              ),
              maxLength: 200,
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: MiraSpacing.base),

            // Style
            Text(
              'Coaching style',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: MiraSpacing.sm),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'warm', label: Text('Warm')),
                ButtonSegment(value: 'direct', label: Text('Direct')),
                ButtonSegment(value: 'playful', label: Text('Playful')),
              ],
              selected: {_style},
              onSelectionChanged: (selected) {
                setState(() => _style = selected.first);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid && !_isCreating ? _create : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 44),
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
