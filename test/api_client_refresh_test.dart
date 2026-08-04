import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/config/api_config.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/core/storage/token_storage.dart';

/// In-memory stand-in for the platform keystore.
final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    final key = args['key'] as String?;

    switch (call.method) {
      case 'read':
        return _secureStore[key];
      case 'write':
        _secureStore[key!] = args['value'] as String;
        return null;
      case 'delete':
        _secureStore.remove(key);
        return null;
      case 'readAll':
        return Map<String, String>.from(_secureStore);
      case 'deleteAll':
        _secureStore.clear();
        return null;
      case 'containsKey':
        return _secureStore.containsKey(key);
      default:
        return null;
    }
  });
}

/// Fresh [TokenStorage] state between tests — the singleton caches in memory.
Future<void> _seedTokens({String? access, String? refresh}) async {
  await TokenStorage.instance.clear();
  await TokenStorage.instance.saveTokens(
    accessToken: access,
    refreshToken: refresh,
  );
}

String _json(Object body) => jsonEncode(body);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    ApiClient.instance.onSessionExpired = null;
  });

  tearDown(() {
    ApiClient.instance.overrideHttpClient(http.Client());
  });

  test('injects the bearer token on authenticated requests', () async {
    await _seedTokens(access: 'access-1', refresh: 'refresh-1');

    String? seenAuth;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      seenAuth = request.headers['Authorization'];
      return http.Response(_json({'success': true, 'data': {}}), 200);
    }));

    await ApiClient.instance.get('/anything');

    expect(seenAuth, 'Bearer access-1');
  });

  test('refreshes once on 401 and replays the original request', () async {
    await _seedTokens(access: 'stale', refresh: 'refresh-1');

    final calls = <String>[];

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      final path = request.url.path;
      calls.add('${request.method} $path');

      if (path.endsWith(ApiEndpoints.refresh)) {
        return http.Response(
          _json({
            'success': true,
            'data': {'accessToken': 'fresh', 'refreshToken': 'refresh-2'},
          }),
          200,
        );
      }

      // First attempt carries the stale token and is rejected.
      if (request.headers['Authorization'] == 'Bearer stale') {
        return http.Response(_json({'message': 'expired'}), 401);
      }

      return http.Response(_json({'success': true, 'data': {'ok': true}}), 200);
    }));

    final response = await ApiClient.instance.get('/protected');

    expect(response.isOk, isTrue);
    expect(calls, [
      'GET /api/protected',
      'POST /api${ApiEndpoints.refresh}',
      'GET /api/protected',
    ]);
    // Rotated tokens are persisted.
    expect(await TokenStorage.instance.accessToken, 'fresh');
    expect(await TokenStorage.instance.refreshToken, 'refresh-2');
  });

  test('collapses concurrent 401s into a single refresh call', () async {
    await _seedTokens(access: 'stale', refresh: 'refresh-1');

    var refreshCalls = 0;

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith(ApiEndpoints.refresh)) {
        refreshCalls++;
        // Delay so the other requests are guaranteed to overlap this one.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return http.Response(
          _json({
            'success': true,
            'data': {'accessToken': 'fresh', 'refreshToken': 'refresh-2'},
          }),
          200,
        );
      }

      if (request.headers['Authorization'] == 'Bearer stale') {
        return http.Response(_json({'message': 'expired'}), 401);
      }
      return http.Response(_json({'success': true, 'data': {}}), 200);
    }));

    await Future.wait([
      ApiClient.instance.get('/a'),
      ApiClient.instance.get('/b'),
      ApiClient.instance.get('/c'),
    ]);

    expect(refreshCalls, 1);
  });

  test('never retries more than once — a second 401 ends the session', () async {
    await _seedTokens(access: 'stale', refresh: 'refresh-1');

    var protectedCalls = 0;
    var sessionExpiredCalls = 0;
    ApiClient.instance.onSessionExpired = () async => sessionExpiredCalls++;

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith(ApiEndpoints.refresh)) {
        return http.Response(
          _json({
            'success': true,
            'data': {'accessToken': 'fresh-but-also-rejected'},
          }),
          200,
        );
      }
      protectedCalls++;
      return http.Response(_json({'message': 'nope'}), 401);
    }));

    await expectLater(
      ApiClient.instance.get('/protected'),
      throwsA(isA<UnauthorizedException>()
          .having((e) => e.sessionExpired, 'sessionExpired', isTrue)),
    );

    // Original + exactly one replay. No loop.
    expect(protectedCalls, 2);
    expect(sessionExpiredCalls, 0, reason: 'refresh itself succeeded');
  });

  test('a rejected refresh clears tokens and signals session expiry', () async {
    await _seedTokens(access: 'stale', refresh: 'refresh-1');

    var sessionExpiredCalls = 0;
    ApiClient.instance.onSessionExpired = () async => sessionExpiredCalls++;

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith(ApiEndpoints.refresh)) {
        return http.Response(_json({'message': 'invalid refresh token'}), 401);
      }
      return http.Response(_json({'message': 'expired'}), 401);
    }));

    await expectLater(
      ApiClient.instance.get('/protected'),
      throwsA(isA<UnauthorizedException>()
          .having((e) => e.sessionExpired, 'sessionExpired', isTrue)),
    );

    expect(sessionExpiredCalls, 1);
    expect(await TokenStorage.instance.accessToken, isNull);
    expect(await TokenStorage.instance.refreshToken, isNull);
  });

  test('a 5xx during refresh keeps the session for a later retry', () async {
    await _seedTokens(access: 'stale', refresh: 'refresh-1');

    var sessionExpiredCalls = 0;
    ApiClient.instance.onSessionExpired = () async => sessionExpiredCalls++;

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith(ApiEndpoints.refresh)) {
        return http.Response('gateway down', 503);
      }
      return http.Response(_json({'message': 'expired'}), 401);
    }));

    await expectLater(
      ApiClient.instance.get('/protected'),
      throwsA(isA<NoInternetException>()),
    );

    expect(sessionExpiredCalls, 0);
    expect(await TokenStorage.instance.refreshToken, 'refresh-1');
  });

  test('maps HTTP status codes onto typed exceptions', () async {
    await _seedTokens(access: 'access-1', refresh: 'refresh-1');

    Future<void> expectStatus(int code, Matcher matcher) async {
      ApiClient.instance.overrideHttpClient(MockClient((_) async =>
          http.Response(_json({'message': 'boom'}), code)));
      await expectLater(ApiClient.instance.get('/x'), throwsA(matcher));
    }

    await expectStatus(400, isA<BadRequestException>());
    await expectStatus(403, isA<ForbiddenException>());
    await expectStatus(404, isA<NotFoundException>());
    await expectStatus(409, isA<ConflictException>());
    await expectStatus(422, isA<ValidationException>());
    await expectStatus(429, isA<RateLimitException>());
    await expectStatus(500, isA<ServerException>());
  });

  test('unauthenticated calls omit the Authorization header', () async {
    await _seedTokens(access: 'access-1', refresh: 'refresh-1');

    Map<String, String>? seen;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      seen = request.headers;
      return http.Response(_json({'success': true, 'data': {}}), 200);
    }));

    await ApiClient.instance
        .post(ApiEndpoints.login, requiresAuth: false, body: {'email': 'a'});

    expect(seen!.containsKey('Authorization'), isFalse);
  });

  test('a guest 401 does not clear state or trigger the logout redirect',
      () async {
    // No tokens at all — the user is browsing public screens.
    await TokenStorage.instance.clear();

    var sessionExpiredCalls = 0;
    ApiClient.instance.onSessionExpired = () async => sessionExpiredCalls++;

    var refreshCalls = 0;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith(ApiEndpoints.refresh)) refreshCalls++;
      return http.Response(_json({'message': 'login required'}), 401);
    }));

    await expectLater(
      ApiClient.instance.get('/protected'),
      throwsA(isA<UnauthorizedException>()
          .having((e) => e.sessionExpired, 'sessionExpired', isFalse)),
    );

    expect(refreshCalls, 0, reason: 'nothing to refresh with');
    expect(sessionExpiredCalls, 0, reason: 'a guest was never signed in');
  });
}
