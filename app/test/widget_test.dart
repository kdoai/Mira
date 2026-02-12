import 'package:flutter_test/flutter_test.dart';
import 'package:mira/models/coach.dart';
import 'package:mira/models/message.dart';
import 'package:mira/services/api_service.dart';

void main() {
  group('Coach model', () {
    test('builtIn list has 5 coaches', () {
      expect(Coach.builtIn.length, 5);
    });

    test('only Mira is free', () {
      final freeCoaches = Coach.builtIn.where((c) => !c.isPro).toList();
      expect(freeCoaches.length, 1);
      expect(freeCoaches.first.id, 'mira');
    });

    test('all pro coaches are built-in', () {
      final proBuiltIn = Coach.builtIn.where((c) => c.isPro && c.isBuiltIn);
      expect(proBuiltIn.length, 4);
    });

    test('fromJson creates custom coach correctly', () {
      final json = {
        'coach_id': 'test-123',
        'name': 'Luna',
        'focus': 'Public speaking',
        'style': 'direct',
        'share_code': 'AB12CD34',
        'is_built_in': false,
        'creator_name': 'Test User',
        'usage_count': 5,
      };
      final coach = Coach.fromJson(json);
      expect(coach.id, 'test-123');
      expect(coach.name, 'Luna');
      expect(coach.focus, 'Public speaking');
      expect(coach.style, 'direct');
      expect(coach.shareCode, 'AB12CD34');
      expect(coach.isBuiltIn, false);
      expect(coach.creatorName, 'Test User');
      expect(coach.usageCount, 5);
    });

    test('fromJson handles missing fields gracefully', () {
      final coach = Coach.fromJson({});
      expect(coach.id, '');
      expect(coach.name, '');
      expect(coach.isBuiltIn, false);
    });
  });

  group('ChatMessage model', () {
    test('apiRole maps assistant to model', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Hello',
        timestamp: DateTime.now(),
      );
      expect(msg.apiRole, 'model');
    });

    test('apiRole keeps user as user', () {
      final msg = ChatMessage(
        role: 'user',
        content: 'Hi',
        timestamp: DateTime.now(),
      );
      expect(msg.apiRole, 'user');
    });

    test('copyWith preserves unchanged fields', () {
      final msg = ChatMessage(
        id: '1',
        role: 'user',
        content: 'Hello',
        timestamp: DateTime(2026, 2, 12),
      );
      final updated = msg.copyWith(content: 'Updated');
      expect(updated.id, '1');
      expect(updated.role, 'user');
      expect(updated.content, 'Updated');
      expect(updated.timestamp, DateTime(2026, 2, 12));
    });

    test('fromJson parses correctly', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg-1',
        'role': 'assistant',
        'content': 'I can help with that.',
        'timestamp': '2026-02-12T10:00:00.000Z',
      });
      expect(msg.id, 'msg-1');
      expect(msg.role, 'assistant');
      expect(msg.content, 'I can help with that.');
    });

    test('toApiJson uses model role for assistant', () {
      final msg = ChatMessage(
        role: 'assistant',
        content: 'Response',
        timestamp: DateTime.now(),
      );
      final json = msg.toApiJson();
      expect(json['role'], 'model');
      expect(json['content'], 'Response');
    });
  });

  group('ApiException', () {
    test('stores message and status code', () {
      final ex = ApiException('Not found', 404);
      expect(ex.message, 'Not found');
      expect(ex.statusCode, 404);
    });

    test('toString includes details', () {
      final ex = ApiException('Server error', 500);
      expect(ex.toString(), 'ApiException(500): Server error');
    });

    test('RateLimitException has 429 status', () {
      final ex = RateLimitException('Too many requests');
      expect(ex.statusCode, 429);
      expect(ex.message, 'Too many requests');
    });
  });
}
