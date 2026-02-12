/// Voice session service — WebSocket + Audio.
/// Ref: PLAN.md Section 5.2, 5.2.1, 5.6 (WS /ws/voice)
///
/// Handles:
/// - WebSocket connection to backend voice proxy
/// - Audio recording (PCM 16kHz mono) and streaming
/// - Audio playback (PCM 24kHz mono) from Gemini
/// - Transcript handling
/// - Echo prevention (mic muted while AI speaks)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:mira/services/auth_service.dart';

/// Callback types for voice events
typedef TranscriptCallback = void Function(String role, String text);
typedef AudioLevelCallback = void Function(double level);

class VoiceService {
  static const String _baseWsUrl =
      'wss://mira-backend-796818796548.us-central1.run.app';

  final AuthService _authService;

  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  WebSocketChannel? _channel;
  StreamSubscription? _wsSubscription;
  StreamController<Uint8List>? _recordingController;

  bool _isSessionActive = false;
  TranscriptCallback? _onTranscript;
  VoidCallback? _onSessionEnded;

  // Audio queue: feed chunks sequentially to prevent native player crash
  final List<Uint8List> _audioQueue = [];
  bool _isProcessingAudio = false;

  // Echo prevention: mute mic sends while AI is speaking.
  // Track actual playback duration to know when speaker finishes.
  bool _isAiSpeaking = false;
  bool _turnCompleteReceived = false;
  Timer? _resumeMicTimer;
  int _totalBytesFed = 0;
  DateTime? _feedStartTime;
  static const int _bytesPerSecond = 48000; // 24kHz × 2 bytes × 1 channel

  // Mic status callback for UI indicator
  void Function(bool isListening)? _onMicStatusChanged;

  VoiceService(this._authService);

  bool get isActive => _isSessionActive;

  /// Request microphone permission.
  Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Start a voice session.
  Future<void> startSession({
    required String conversationId,
    required String coachId,
    required TranscriptCallback onTranscript,
    required VoidCallback onSessionEnded,
    AudioLevelCallback? onAudioLevel,
    void Function(bool isListening)? onMicStatusChanged,
  }) async {
    if (_isSessionActive) return;

    _onTranscript = onTranscript;
    _onSessionEnded = onSessionEnded;
    _onMicStatusChanged = onMicStatusChanged;

    // Get auth token
    final token = await _authService.getIdToken();
    if (token == null) throw Exception('Not authenticated');

    // Connect WebSocket
    final wsUrl = '$_baseWsUrl/ws/voice/$conversationId?token=$token&coach_id=$coachId';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

    // Listen for messages from server
    _wsSubscription = _channel!.stream.listen(
      (message) => _handleServerMessage(message),
      onError: (error) {
        _cleanup();
      },
      onDone: () {
        _cleanup();
      },
    );

    // Initialize recorder
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();

    // Initialize player with large buffer for smooth playback
    _player = FlutterSoundPlayer();
    await _player!.openPlayer();
    await _player!.startPlayerFromStream(
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
      bufferSize: 32768,
      interleaved: true,
    );

    _isSessionActive = true;
    _onMicStatusChanged?.call(true); // Mic starts active

    // Start recording and streaming audio
    _recordingController = StreamController<Uint8List>();
    _recordingController!.stream.listen((buffer) {
      // Don't send mic data while AI is speaking (echo prevention)
      if (_isSessionActive && _channel != null && !_isAiSpeaking) {
        final base64Audio = base64Encode(buffer);
        _channel!.sink.add(json.encode({
          'type': 'audio',
          'data': base64Audio,
        }));
      }
    });

    await _recorder!.startRecorder(
      toStream: _recordingController!.sink,
      codec: Codec.pcm16,
      sampleRate: 16000,
      numChannels: 1,
    );
  }

  void _handleServerMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      final type = data['type'] as String?;

      switch (type) {
        case 'audio':
          // Cancel any pending mic resume — audio is still arriving
          _resumeMicTimer?.cancel();
          if (!_isAiSpeaking) {
            _isAiSpeaking = true;
            _turnCompleteReceived = false;
            _totalBytesFed = 0;
            _feedStartTime = null;
            _onMicStatusChanged?.call(false);
            debugPrint('[Voice] AI speaking — mic muted');
          }
          // Queue chunk directly for sequential playback (no accumulation)
          final audioData = data['data'] as String;
          final audioBytes = base64Decode(audioData);
          _audioQueue.add(Uint8List.fromList(audioBytes));
          _processAudioQueue();
          break;

        case 'turn_complete':
          // AI finished generating — but audio may still be playing
          debugPrint('[Voice] turn complete received');
          _turnCompleteReceived = true;
          _scheduleResumeMic();
          break;

        case 'transcript':
          final role = data['role'] as String? ?? 'assistant';
          final text = data['text'] as String? ?? '';
          debugPrint('[Voice] transcript ($role): $text');
          _onTranscript?.call(role, text);
          break;

        case 'error':
          final errorMsg = data['message'] as String? ?? 'Voice error';
          debugPrint('[Voice] error: $errorMsg');
          _onTranscript?.call('system', errorMsg);
          break;

        case 'session_ended':
          debugPrint('[Voice] session ended');
          _cleanup();
          _onSessionEnded?.call();
          break;

        case 'ping':
          break;

        default:
          debugPrint('[Voice] unknown message type: $type');
      }
    } catch (e) {
      debugPrint('[Voice] message parse error: $e');
    }
  }

  /// Process queued audio chunks — merge all available chunks into a single
  /// feed call to reduce native bridge overhead and prevent buffer underrun.
  Future<void> _processAudioQueue() async {
    if (_isProcessingAudio) return;
    _isProcessingAudio = true;
    try {
      // On first feed of a new speaking turn, wait briefly to let
      // initial chunks accumulate for smoother playback start.
      if (_totalBytesFed == 0 && _audioQueue.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 120));
      }
      while (_audioQueue.isNotEmpty && _isSessionActive) {
        // Snapshot and clear queue, then merge all chunks into one feed
        final chunks = List<Uint8List>.from(_audioQueue);
        _audioQueue.clear();
        final builder = BytesBuilder(copy: false);
        for (final c in chunks) {
          builder.add(c);
        }
        final merged = builder.takeBytes();
        try {
          await _player?.feedUint8FromStream(merged);
          _totalBytesFed += merged.length;
          _feedStartTime ??= DateTime.now();
        } catch (e) {
          debugPrint('[Voice] audio feed error: $e');
        }
      }
    } finally {
      _isProcessingAudio = false;
    }
    // Queue drained — check if we can schedule mic resume
    _scheduleResumeMic();
  }

  /// Resume mic only after the speaker has finished playing all buffered audio.
  /// Calculates remaining playback time from total bytes fed and elapsed time.
  void _scheduleResumeMic() {
    if (!_isAiSpeaking) return;
    if (_audioQueue.isNotEmpty || _isProcessingAudio) return;

    // If turn_complete hasn't arrived yet, set a fallback timer
    if (!_turnCompleteReceived) {
      _resumeMicTimer?.cancel();
      _resumeMicTimer = Timer(const Duration(milliseconds: 3000), () {
        _resetMicState();
        debugPrint('[Voice] mic unmuted (fallback — no turn_complete)');
      });
      return;
    }

    // Calculate remaining playback time
    final totalDurationMs =
        (_totalBytesFed / _bytesPerSecond * 1000).round();
    final elapsedMs = _feedStartTime != null
        ? DateTime.now().difference(_feedStartTime!).inMilliseconds
        : 0;
    final remainingMs = totalDurationMs - elapsedMs;
    // Add 800ms margin for speaker buffer drain + echo decay
    final delayMs = (remainingMs > 0 ? remainingMs : 0) + 800;

    debugPrint(
      '[Voice] scheduling mic resume in ${delayMs}ms '
      '(audio=${totalDurationMs}ms, elapsed=${elapsedMs}ms)',
    );

    _resumeMicTimer?.cancel();
    _resumeMicTimer = Timer(Duration(milliseconds: delayMs), () {
      _resetMicState();
      debugPrint('[Voice] mic unmuted');
    });
  }

  void _resetMicState() {
    _isAiSpeaking = false;
    _turnCompleteReceived = false;
    _totalBytesFed = 0;
    _feedStartTime = null;
    _onMicStatusChanged?.call(true);
  }

  /// End the current voice session.
  Future<void> endSession() async {
    if (!_isSessionActive) return;

    try {
      _channel?.sink.add(json.encode({'type': 'end_session'}));
    } catch (_) {}

    await _cleanup();
    _onSessionEnded?.call();
  }

  Future<void> _cleanup() async {
    _isSessionActive = false;
    _isProcessingAudio = false;
    _resumeMicTimer?.cancel();
    _resetMicState();
    _audioQueue.clear();

    // Close recording stream controller first (stops mic data flow)
    try {
      await _recordingController?.close();
    } catch (_) {}
    _recordingController = null;

    try {
      await _recorder?.stopRecorder();
      await _recorder?.closeRecorder();
    } catch (_) {}

    try {
      await _player?.stopPlayer();
      await _player?.closePlayer();
    } catch (_) {}

    _wsSubscription?.cancel();
    _channel?.sink.close();

    _recorder = null;
    _player = null;
    _channel = null;
    _wsSubscription = null;
    _onMicStatusChanged = null;
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await _cleanup();
  }
}
