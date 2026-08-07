import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/repositories/auth_repository.dart';

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
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
      default:
        return null;
    }
  });
}

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

/// The documented `POST /auth/register` response, verbatim.
Map<String, dynamic> _registerResponse() => {
      'success': true,
      'message': 'User registered successfully',
      'data': {
        'user': {
          'id': 599,
          'name': 'test',
          'email': 'testrahul@example.com',
          'role': 'USER',
          'phone_number': '8989565623',
        },
        'accessToken': 'access-token-599',
        'refreshToken': 'refresh-token-599',
      },
    };

/// What `/auth/profile` answers straight after — the permissions the sign-up
/// response leaves out.
Map<String, dynamic> _profileResponse() => {
      'success': true,
      'user': {
        'id': 599,
        'name': 'test',
        'email': 'testrahul@example.com',
        'role': 'USER',
        'phone_number': '8989565623',
        'permissions': ['user_dashboard', 'user_my_bookings'],
      },
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // TokenStorage keeps an in-memory copy, so emptying the mock keychain is
    // not enough to un-sign-in between tests.
    await TokenStorage.instance.clear();
  });

  tearDown(() async {
    ApiClient.instance.overrideHttpClient(http.Client());
    PermissionService.instance.clear();
  });

  group('AuthRepository.signUp', () {
    test('stores the session and reads the profile for its permissions',
        () async {
      final paths = <String>[];
      Map<String, dynamic>? sentBody;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/auth/register')) {
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(_registerResponse());
          }
          return _json(_profileResponse());
        }),
      );

      final result = await AuthRepository.instance.signUp(
        name: 'test',
        email: 'testrahul@example.com',
        password: '123456789',
        phoneNumber: '8989565623',
      );

      expect(result.success, isTrue);
      expect(result.profile?.id, 599);
      expect(result.profile?.email, 'testrahul@example.com');
      expect(result.profile?.roleKey, 'user');

      // The documented body, and nothing else.
      expect(sentBody, {
        'name': 'test',
        'email': 'testrahul@example.com',
        'password': '123456789',
        'phone_number': '8989565623',
      });

      // Signed in: the tokens from the sign-up are what the app now carries.
      expect(await TokenStorage.instance.accessToken, 'access-token-599');
      expect(await TokenStorage.instance.hasSession, isTrue);

      // /auth/profile was re-read, so the permissions are present even though
      // the register response carried none.
      expect(paths.any((p) => p.endsWith('/auth/profile')), isTrue);
      expect(
        PermissionService.instance.hasPermission('user_my_bookings'),
        isTrue,
      );
    });

    test('still signs in when the follow-up profile read fails', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/register')) {
            return _json(_registerResponse());
          }
          return _json({'message': 'boom'}, status: 500);
        }),
      );

      final result = await AuthRepository.instance.signUp(
        name: 'test',
        email: 'testrahul@example.com',
        password: '123456789',
        phoneNumber: '8989565623',
      );

      // The account exists and the tokens are good; a failed profile read must
      // not throw that away.
      expect(result.success, isTrue);
      expect(result.profile?.id, 599);
      expect(await TokenStorage.instance.hasSession, isTrue);
    });

    test('surfaces a rejection as a failure, not an exception', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient(
          (_) async => _json(
            {'success': false, 'message': 'Email already registered'},
            status: 409,
          ),
        ),
      );

      final result = await AuthRepository.instance.signUp(
        name: 'test',
        email: 'taken@example.com',
        password: '123456789',
        phoneNumber: '8989565623',
      );

      expect(result.success, isFalse);
      expect(result.message, contains('already registered'));
      expect(await TokenStorage.instance.hasSession, isFalse);
    });

    group('validates before the round trip', () {
      late bool called;

      setUp(() {
        called = false;
        ApiClient.instance.overrideHttpClient(
          MockClient((_) async {
            called = true;
            return _json(_registerResponse());
          }),
        );
      });

      Future<void> expectRejected({
        String name = 'test',
        String email = 'testrahul@example.com',
        String password = '123456789',
        String phone = '8989565623',
      }) async {
        await expectLater(
          AuthRepository.instance.signUp(
            name: name,
            email: email,
            password: password,
            phoneNumber: phone,
          ),
          throwsA(isA<Exception>()),
        );
        expect(called, isFalse);
      }

      test('an empty name', () => expectRejected(name: '   '));
      test('a malformed email', () => expectRejected(email: 'not-an-email'));
      test('a short password', () => expectRejected(password: '12345'));
      test('a 9-digit phone', () => expectRejected(phone: '898956562'));
    });

    test('strips formatting from the phone number', () async {
      Map<String, dynamic>? sentBody;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          if (request.url.path.endsWith('/auth/register')) {
            sentBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(_registerResponse());
          }
          return _json(_profileResponse());
        }),
      );

      await AuthRepository.instance.signUp(
        name: '  test  ',
        email: '  testrahul@example.com ',
        password: '123456789',
        phoneNumber: '898-956 5623',
      );

      expect(sentBody?['phone_number'], '8989565623');
      expect(sentBody?['name'], 'test');
      expect(sentBody?['email'], 'testrahul@example.com');
    });
  });
}