/// REST API client for Mira backend.
/// Ref: PLAN.md Section 5.1 (SSE streaming), Section 5.6 (API Contracts)
///
/// All requests require Firebase ID token in Authorization header.
/// Chat uses SSE streaming for real-time response chunks.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:mira/models/conversation.dart';
import 'package:mira/models/message.dart';
import 'package:mira/models/session_report.dart';
import 'package:mira/models/user_profile.dart';
import 'package:mira/services/auth_service.dart';

class ApiService {
  // TODO: Update after Cloud Run deployment
  static const String _baseUrl = 'https://mira-backend-796818796548.us-central1.run.app';
  String get baseUrl => _baseUrl;

  final AuthService _authService;

  ApiService(this._authService);

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  // === Chat ===
  // Ref: PLAN.md Section 5.1, 5.6 (POST /chat/send)

  /// Send message and receive SSE streaming response.
  /// Returns a Stream of text chunks.
  Stream<String> sendMessage({
    required String coachId,
    required String message,
    required List<ChatMessage> history,
    required String conversationId,
  }) async* {
    final token = await _authService.getIdToken();
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/send'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({
      'coach_id': coachId,
      'message': message,
      'conversation_id': conversationId,
      'history': history.map((m) => m.toApiJson()).toList(),
    });

    final response = await http.Client().send(request);

    if (response.statusCode == 429) {
      throw RateLimitException(
        'Daily limit reached. Upgrade to Pro for unlimited messages.',
      );
    }

    if (response.statusCode != 200) {
      throw ApiException('Chat request failed', response.statusCode);
    }

    // Parse SSE stream with proper line buffering
    // Ref: PLAN.md Section 5.1 (Frontend SSE consumption)
    String buffer = '';
    String currentEvent = 'message';
    await for (final rawChunk in response.stream.transform(utf8.decoder)) {
      buffer += rawChunk;

      // Process complete lines from buffer
      while (buffer.contains('\n')) {
        final idx = buffer.indexOf('\n');
        final line = buffer.substring(0, idx).replaceAll('\r', '');
        buffer = buffer.substring(idx + 1);

        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
          continue;
        }

        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr.isEmpty) continue;

          // Handle error events from backend
          if (currentEvent == 'error') {
            try {
              final data = json.decode(dataStr);
              final error = data['error'] ?? data['detail'] ?? 'Unknown error';
              throw ApiException(error.toString(), 200);
            } catch (e) {
              if (e is ApiException) rethrow;
              throw ApiException(dataStr, 200);
            }
          }

          try {
            final data = json.decode(dataStr);
            final text = data['text'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
            }
          } catch (_) {
            // Skip malformed SSE data
          }
          currentEvent = 'message';
        }
      }
    }
  }

  // === Conversations ===
  // Ref: PLAN.md Section 5.6 (GET /conversations)

  Future<List<Conversation>> getConversations({
    int limit = 20,
    int offset = 0,
  }) async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/conversations?limit=$limit&offset=$offset'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to load conversations', response.statusCode);
    }

    final data = json.decode(response.body);
    final list = data['conversations'] as List;
    return list.map((c) => Conversation.fromJson(c)).toList();
  }

  Future<List<ChatMessage>> getMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/conversations/$conversationId/messages?limit=$limit'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to load messages', response.statusCode);
    }

    final data = json.decode(response.body);
    final list = data['messages'] as List;
    return list.map((m) => ChatMessage.fromJson(m)).toList();
  }

  // === Session Reports ===
  // Ref: PLAN.md Section 5.6 (POST /conversations/{id}/report)

  Future<SessionReport> generateReport(String conversationId) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/conversations/$conversationId/report'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to generate report', response.statusCode);
    }

    return SessionReport.fromJson(json.decode(response.body));
  }

  Future<void> deleteConversation(String conversationId) async {
    final headers = await _headers();
    final response = await http.delete(
      Uri.parse('$baseUrl/conversations/$conversationId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to delete conversation', response.statusCode);
    }
  }

  Future<void> updateActionStatus({
    required String conversationId,
    required String actionStatus,
  }) async {
    final headers = await _headers();
    final response = await http.patch(
      Uri.parse('$baseUrl/conversations/$conversationId/action-status'),
      headers: headers,
      body: json.encode({'action_status': actionStatus}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update action status', response.statusCode);
    }
  }

  // === Subscription ===

  Future<void> syncSubscription() async {
    final headers = await _headers();
    await http.post(
      Uri.parse('$baseUrl/profile/subscription/sync'),
      headers: headers,
    );
  }

  // === Profile ===
  // Ref: PLAN.md Section 5.6 (GET /profile, PUT /profile/about-me)

  Future<UserProfile> getProfile() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/profile'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to load profile', response.statusCode);
    }

    return UserProfile.fromJson(json.decode(response.body));
  }

  Future<void> updateAboutMe(String freeText) async {
    final headers = await _headers();
    final response = await http.put(
      Uri.parse('$baseUrl/profile/about-me'),
      headers: headers,
      body: json.encode({'free_text': freeText}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update About Me', response.statusCode);
    }
  }

  // === Coaches ===
  // Ref: PLAN.md Section 5.6 (POST /coaches/create, GET /coaches/shared)

  Future<Map<String, dynamic>> createCoach({
    required String name,
    required String focus,
    required String style,
  }) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/coaches/create'),
      headers: headers,
      body: json.encode({
        'name': name,
        'focus': focus,
        'style': style,
      }),
    );

    if (response.statusCode != 201) {
      throw ApiException('Failed to create coach', response.statusCode);
    }

    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> getSharedCoach(String shareCode) async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/coaches/shared/$shareCode'),
      headers: headers,
    );

    if (response.statusCode == 404) {
      throw ApiException('Coach not found', 404);
    }
    if (response.statusCode != 200) {
      throw ApiException('Failed to load shared coach', response.statusCode);
    }

    return json.decode(response.body);
  }

  Future<void> addSharedCoach(String shareCode) async {
    final headers = await _headers();
    final response = await http.post(
      Uri.parse('$baseUrl/coaches/add/$shareCode'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to add coach', response.statusCode);
    }
  }

  Future<List<Map<String, dynamic>>> getMyCoaches() async {
    final headers = await _headers();
    final response = await http.get(
      Uri.parse('$baseUrl/coaches/mine'),
      headers: headers,
    );

    if (response.statusCode != 200) return [];
    final data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(data['coaches'] ?? []);
  }

  Future<void> updateDisplayName(String name) async {
    final headers = await _headers();
    final response = await http.put(
      Uri.parse('$baseUrl/profile/display-name'),
      headers: headers,
      body: json.encode({'name': name}),
    );

    if (response.statusCode != 200) {
      throw ApiException('Failed to update name', response.statusCode);
    }
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class RateLimitException extends ApiException {
  RateLimitException(String message) : super(message, 429);
}
