import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/repositories/auth_repository.dart';

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
      case 'deleteAll':
        _secureStore.clear();
        return null;
      case 'readAll':
        return Map<String, String>.from(_secureStore);
      default:
        return null;
    }
  });
}

/// Verbatim response from `POST /auth/logout`.
const Map<String, dynamic> _loggedOut = {
  'success': true,
  'message': 'Logout successful'
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    await TokenStorage.instance.clear();

    requests = <http.Request>[];
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  void serve(Object body, {int status = 200}) {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status);
    }));
  }

  Future<void> signIn() => TokenStorage.instance
      .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

  test('tells the server, with the token still attached', () async {
    await signIn();
    serve(_loggedOut);

    final acknowledged = await AuthRepository.instance.logout();

    expect(acknowledged, isTrue);
    expect(requests.single.url.path, '/api/auth/logout');
    expect(requests.single.method, 'POST');
    expect(requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('the session is gone afterwards', () async {
    await signIn();
    serve(_loggedOut);

    await AuthRepository.instance.logout();

    expect(await TokenStorage.instance.hasSession, isFalse);
    expect(await TokenStorage.instance.accessToken, isNull);
    expect(await TokenStorage.instance.refreshToken, isNull);
  });

  test('a rejected logout still signs the user out locally', () async {
    await signIn();
    serve({'success': false, 'message': 'Token already revoked'}, status: 401);

    final acknowledged = await AuthRepository.instance.logout();

    expect(acknowledged, isFalse);
    expect(await TokenStorage.instance.hasSession, isFalse);
  });

  test('a network failure still signs the user out locally', () async {
    await signIn();
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      throw const SocketExceptionStub();
    }));

    final acknowledged = await AuthRepository.instance.logout();

    expect(acknowledged, isFalse);
    expect(await TokenStorage.instance.hasSession, isFalse);
  });

  test('with no session there is nothing to tell the server', () async {
    serve(_loggedOut);

    final acknowledged = await AuthRepository.instance.logout();

    expect(acknowledged, isFalse);
    expect(requests, isEmpty);
  });
}

/// Stands in for a transport failure without importing dart:io into the test.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
