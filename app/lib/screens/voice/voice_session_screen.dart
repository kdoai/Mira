/// Voice session screen — animated gradient orb + live transcript.
/// Ref: PLAN.md Section 5.2 (Voice Session), Section 3.3 (Voice Visualizer)
///
/// Features:
/// - Animated gradient orb (hero moment for demo)
/// - Real-time transcripts below orb
/// - End session button
/// - Timer display
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:mira/providers/coaches_provider.dart';
import 'package:mira/providers/voice_provider.dart';
import 'package:mira/theme/app_theme.dart';
import 'package:mira/widgets/voice_visualizer.dart';

const _uuid = Uuid();

class VoiceSessionScreen extends ConsumerStatefulWidget {
  final String coachId;

  const VoiceSessionScreen({super.key, required this.coachId});

  @override
  ConsumerState<VoiceSessionScreen> createState() =>
      _VoiceSessionScreenState();
}

class _VoiceSessionScreenState extends ConsumerState<VoiceSessionScreen> {
  late String _conversationId;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isConnecting = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _conversationId = _uuid.v4();
    _startSession();
  }

  Future<void> _startSession() async {
    final voiceService = ref.read(voiceServiceProvider);

    // Request mic permission
    final hasPermission = await voiceService.requestMicPermission();
    if (!hasPermission) {
      setState(() {
        _error = 'Microphone access is required for voice sessions.';
        _isConnecting = false;
      });
      return;
    }

    try {
      await voiceService.startSession(
        conversationId: _conversationId,
        coachId: widget.coachId,
        onTranscript: (role, text) {
          ref.read(voiceTranscriptsProvider.notifier).add(role, text);
        },
        onSessionEnded: () {
          _stopTimer();
          ref.read(isVoiceActiveProvider.notifier).state = false;
          if (mounted) {
            context.go('/home');
          }
        },
        onMicStatusChanged: (isListening) {
          if (mounted) {
            ref.read(isMicListeningProvider.notifier).state = isListening;
          }
        },
      );

      ref.read(isVoiceActiveProvider.notifier).state = true;
      ref.read(voiceTranscriptsProvider.notifier).clear();
      setState(() => _isConnecting = false);
      _startTimer();
    } catch (e) {
      setState(() {
        _error = 'Failed to start voice session. Please try again.';
        _isConnecting = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _endSession() async {
    _stopTimer();
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.endSession();
    ref.read(isVoiceActiveProvider.notifier).state = false;
    if (mounted) context.go('/home');
  }

  /// End session without navigating — used when switching to text chat.
  Future<void> _endSessionSilent() async {
    _stopTimer();
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.endSession();
    ref.read(isVoiceActiveProvider.notifier).state = false;
  }

  String get _timerText {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coach =
        ref.read(coachesProvider.notifier).getCoach(widget.coachId);
    final transcripts = ref.watch(voiceTranscriptsProvider);
    final isMicListening = ref.watch(isMicListeningProvider);

    return Scaffold(
      backgroundColor: MiraColors.warmWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _endSession,
        ),
        title: Text(coach?.name ?? 'Voice Session'),
        actions: [
          IconButton(
            onPressed: () async {
              await _endSessionSilent();
              if (mounted) context.push('/chat/${widget.coachId}');
            },
            icon: const Icon(Icons.chat_outlined),
            tooltip: 'Switch to text',
          ),
        ],
      ),
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Animated gradient orb
              // Ref: PLAN.md Section 3.3 (Voice Visualizer — hero moment)
              if (_error.isNotEmpty)
                _buildError(context)
              else if (_isConnecting)
                _buildConnecting(context)
              else
                Center(
                  child: VoiceVisualizer(
                    color: coach?.color ?? MiraColors.forestGreen,
                    isActive: true,
                  ),
                ),

              const SizedBox(height: MiraSpacing.lg),

              // Timer
              if (!_isConnecting && _error.isEmpty)
                Center(
                  child: Text(
                    _timerText,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: MiraColors.textSecondary,
                            ),
                  ),
                ),

              // Mic status indicator
              if (!_isConnecting && _error.isEmpty) ...[
                const SizedBox(height: MiraSpacing.md),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isMicListening
                              ? MiraColors.forestGreen
                              : MiraColors.textTertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: MiraSpacing.sm),
                      Text(
                        isMicListening
                            ? 'Listening...'
                            : 'Coach is speaking',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isMicListening
                                      ? MiraColors.forestGreen
                                      : MiraColors.textTertiary,
                                ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 1),

              // Transcripts
              if (transcripts.isNotEmpty)
                SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MiraSpacing.pagePadding,
                    ),
                    child: ListView.builder(
                      reverse: true,
                      itemCount: transcripts.length,
                      itemBuilder: (context, index) {
                        final t =
                            transcripts[transcripts.length - 1 - index];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: MiraSpacing.sm),
                          child: Text(
                            '${t.role == 'user' ? 'You' : coach?.name ?? 'Coach'}: ${t.text}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: t.role == 'user'
                                      ? MiraColors.textPrimary
                                      : MiraColors.forestGreen,
                                ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // End session button
              Padding(
                padding: const EdgeInsets.all(MiraSpacing.xl),
                child: GestureDetector(
                  onTap: _endSession,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: MiraColors.error,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.call_end,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnecting(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            color: MiraColors.forestGreen,
            strokeWidth: 3,
          ),
        ),
        const SizedBox(height: MiraSpacing.base),
        Text(
          'Connecting...',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: MiraColors.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MiraSpacing.xl),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: MiraColors.error,
          ),
          const SizedBox(height: MiraSpacing.base),
          Text(
            _error,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: MiraColors.textSecondary,
                ),
          ),
          const SizedBox(height: MiraSpacing.base),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }
}
