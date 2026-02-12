/// About Me screen — single free-text field.
/// Ref: PLAN.md Section 3.3, 3.5 (About Me = single free-text field)
///
/// Accessible from Profile tab. Max 500 chars.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mira/providers/chat_provider.dart';
import 'package:mira/theme/app_theme.dart';

class AboutMeScreen extends ConsumerStatefulWidget {
  const AboutMeScreen({super.key});

  @override
  ConsumerState<AboutMeScreen> createState() => _AboutMeScreenState();
}

class _AboutMeScreenState extends ConsumerState<AboutMeScreen> {
  final _controller = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAboutMe();
  }

  Future<void> _loadAboutMe() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final profile = await apiService.getProfile();
      _controller.text = profile.aboutMe;
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.updateAboutMe(_controller.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('About Me updated!')),
        );
        context.go('/profile');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/profile'),
        ),
        title: const Text('About Me'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: MiraColors.forestGreen,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(MiraSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tell your coach about yourself',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: MiraSpacing.sm),
                  Text(
                    'Share your goals, challenges, values, or anything that helps your coach understand you better. This context is used in every session.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MiraColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: MiraSpacing.base),
                  TextField(
                    controller: _controller,
                    maxLength: 500,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g. I\'m a 28-year-old software engineer considering a career change. I value creativity and work-life balance...',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
