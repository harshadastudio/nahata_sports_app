import 'dart:convert';
import 'dart:io';

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
      case 'readAll':
        return Map<String, String>.from(_secureStore);
      default:
        return null;
    }
  });
}

/// Verbatim success payload from `POST /students/register`.
const Map<String, dynamic> _registered = {
  'success': true,
  'message': 'Student registered successfully.',
  'data': {
    'user': {
      'id': 572,
      'name': 'Demo',
      'email': 'demoo@gmail.com',
      'phone_number': '9423091217',
      'dob': '2003-03-30',
      'gender': 'Male',
      'blood_group': 'B-',
      'avatar':
          'https://api.nahatasports.com/uploads/nahata-sports/students/students-1785412651365-276340759.png',
      'role': 'USER',
      'status': 'Active',
      'join_date': '2026-07-30'
    },
    'student': {
      'id': 47,
      'parentName': null,
      'parentPhone': null,
      'parentEmail': null,
      'schoolName': null,
      'grade': null,
      'enrollmentDate': '2026-07-30',
      'status': 'Active'
    }
  }
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.BaseRequest> requests;
  late List<String> bodies;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    await TokenStorage.instance.clear();

    requests = <http.BaseRequest>[];
    bodies = <String>[];
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  void serve(Object body, {int status = 200}) {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      bodies.add(request.body);
      return http.Response(jsonEncode(body), status);
    }));
  }

  Future<RegistrationResult> register({
    String? dob = '2003-03-30',
    String? gender = 'Male',
    String? bloodGroup,
    String? referral,
    String? avatarPath,
  }) {
    return AuthRepository.instance.register(
      name: 'Demo',
      phone: '9423091217',
      email: 'demoo@gmail.com',
      sportComplexId: 1,
      password: 'secret123',
      confirmPassword: 'secret123',
      dob: dob,
      gender: gender,
      bloodGroup: bloodGroup,
      referralCode: referral,
      avatarPath: avatarPath,
    );
  }

  group('the request', () {
    test('goes to /students/register without a session', () async {
      serve(_registered);
      await register();

      expect(requests.single.url.path, '/api/students/register');
      expect(requests.single.method, 'POST');
      // Registration happens before there is any token.
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
    });

    test('carries every mandatory field', () async {
      serve(_registered);
      await register(dob: null, gender: null);

      final body = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect(body, {
        'name': 'Demo',
        'email': 'demoo@gmail.com',
        'phone_number': '9423091217',
        'password': 'secret123',
        'confirmPassword': 'secret123',
        'sportComplexId': 1,
      });
    });

    test('adds the optional fields only when they are filled in', () async {
      serve(_registered);
      await register(bloodGroup: 'B-', referral: 'NAH123');

      final body = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect(body['dob'], '2003-03-30');
      expect(body['gender'], 'Male');
      expect(body['blood_group'], 'B-');
      expect(body['referral_code'], 'NAH123');
    });

    test('empty optional fields are left out entirely', () async {
      serve(_registered);
      await register(dob: '', gender: '', bloodGroup: '', referral: '');

      final body = jsonDecode(bodies.single) as Map<String, dynamic>;
      expect(body.containsKey('dob'), isFalse);
      expect(body.containsKey('gender'), isFalse);
      expect(body.containsKey('blood_group'), isFalse);
      expect(body.containsKey('referral_code'), isFalse);
    });

    test('a chosen photo makes it a multipart upload', () async {
      serve(_registered);

      final file = File(
          '${Directory.systemTemp.createTempSync('reg').path}/avatar.png');
      await file.writeAsBytes(<int>[1, 2, 3]);

      await register(avatarPath: file.path);

      // MockClient hands back the finalised request, so the multipart shape is
      // asserted through its content type and encoded body.
      expect(requests.single.headers['content-type'] ??
          requests.single.headers['Content-Type'],
          startsWith('multipart/form-data'));

      final body = bodies.single;
      expect(body, contains('name="name"'));
      expect(body, contains('Demo'));
      expect(body, contains('name="sportComplexId"'));
      expect(body, contains('name="avatar"'));
      expect(body, contains('filename="avatar.png"'));
    });
  });

  group('the response', () {
    test('reads the created user and student', () async {
      serve(_registered);
      final result = await register();

      expect(result.success, isTrue);
      expect(result.message, 'Student registered successfully.');
      expect(result.user?['id'], 572);
      expect(result.user?['email'], 'demoo@gmail.com');
      expect(result.user?['phone_number'], '9423091217');
      expect(result.user?['role'], 'USER');
      expect(result.user?['avatar'], contains('students-1785412651365'));
      expect(result.student?['id'], 47);
      expect(result.student?['status'], 'Active');
    });

    test('a rejected registration surfaces the server message', () async {
      serve({'success': false, 'message': 'Email already registered'},
          status: 400);

      final result = await register();

      expect(result.success, isFalse);
      expect(result.message, 'Email already registered');
      expect(result.user, isNull);
    });

    test('field errors are exposed for the form', () async {
      serve({
        'success': false,
        'message': 'Validation failed',
        'errors': {
          'phone_number': ['Phone number is already in use']
        }
      }, status: 422);

      final result = await register();

      expect(result.success, isFalse);
      expect(result.firstFieldError, 'Phone number is already in use');
    });

    test('a server error does not throw at the screen', () async {
      serve({'success': false, 'message': 'Server error'}, status: 500);

      expect((await register()).success, isFalse);
    });
  });
}
