import 'package:flutter_test/flutter_test.dart';
import 'package:kinder_world/core/api/ai_buddy_api.dart';
import 'package:kinder_world/core/network/network_service.dart';
import 'package:kinder_world/core/services/ai_buddy_service.dart';
import 'package:kinder_world/core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class _FakeSecureStorage extends SecureStorage {
  _FakeSecureStorage({
    this.parentAccessToken,
    this.authToken,
  });

  final String? parentAccessToken;
  final String? authToken;

  @override
  Future<String?> getParentAccessToken() async => parentAccessToken;

  @override
  Future<String?> getAuthToken() async => authToken;
}

class _FakeAiBuddyApi extends AiBuddyApi {
  _FakeAiBuddyApi()
      : super(
          NetworkService(
            secureStorage: _FakeSecureStorage(),
            logger: Logger(),
          ),
        );

  String? lastAccessToken;

  @override
  Future<Map<String, dynamic>> getCurrentSession({
    required int childId,
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    return {
      'session': null,
      'messages': const [],
      'provider': {
        'configured': false,
        'mode': 'internal_fallback',
        'status': 'fallback',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> startSession({
    required int childId,
    required String accessToken,
    bool forceNew = false,
    String? locale,
  }) async {
    lastAccessToken = accessToken;
    return {
      'session': {
        'id': 1,
        'child_id': childId,
        'parent_user_id': 1,
        'status': 'active',
        'provider_mode': 'internal_fallback',
        'provider_status': 'fallback',
        'visibility_mode': 'summary_only',
        'messages_count': 1,
      },
      'messages': const [],
      'provider': {
        'configured': false,
        'mode': 'internal_fallback',
        'status': 'fallback',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> deleteChildHistory({
    required int childId,
    required String accessToken,
  }) async {
    lastAccessToken = accessToken;
    return {
      'success': true,
      'child_id': childId,
    };
  }
}

void main() {
  test('AI Buddy prefers the stored parent access token when available',
      () async {
    final api = _FakeAiBuddyApi();
    final service = AiBuddyService(
      api: api,
      secureStorage: _FakeSecureStorage(
        parentAccessToken: 'parent-token',
      ),
      logger: Logger(),
    );

    final result = await service.deleteChildHistory(childId: 7);

    expect(result['success'], isTrue);
    expect(api.lastAccessToken, 'parent-token');
  });

  test('AI Buddy uses the current auth token for child conversation access',
      () async {
    final api = _FakeAiBuddyApi();
    final service = AiBuddyService(
      api: api,
      secureStorage: _FakeSecureStorage(
        authToken: 'child-session-token',
        parentAccessToken: '',
      ),
      logger: Logger(),
    );

    await service.getOrStartCurrentSession(childId: 9);

    expect(api.lastAccessToken, 'child-session-token');
  });

  test('AI Buddy still requires parent auth for parent-only history actions',
      () async {
    final service = AiBuddyService(
      api: _FakeAiBuddyApi(),
      secureStorage: _FakeSecureStorage(
        authToken: 'child-session-token',
        parentAccessToken: '',
      ),
      logger: Logger(),
    );

    expect(
      () => service.deleteChildHistory(childId: 9),
      throwsA(
        isA<AiBuddyUnavailableException>().having(
          (error) => error.message,
          'message',
          'Authentication is required to use AI Buddy.',
        ),
      ),
    );
  });

  test('AI Buddy throws when neither parent nor auth tokens are available',
      () async {
    final service = AiBuddyService(
      api: _FakeAiBuddyApi(),
      secureStorage: _FakeSecureStorage(),
      logger: Logger(),
    );

    expect(
      () => service.deleteChildHistory(childId: 5),
      throwsA(
        isA<AiBuddyUnavailableException>().having(
          (error) => error.message,
          'message',
          'Authentication is required to use AI Buddy.',
        ),
      ),
    );
  });
}
