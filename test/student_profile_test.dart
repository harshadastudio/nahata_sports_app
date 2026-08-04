import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/student_profile_model.dart';
import 'package:nahata_app/repositories/user_repository.dart';

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

/// Verbatim response from `GET /students/me`.
const Map<String, dynamic> _me = {
  'success': true,
  'data': {
    'id': 45,
    'userId': 569,
    'sportComplexId': null,
    'parentName': null,
    'parentPhone': null,
    'parentEmail': null,
    'schoolName': null,
    'grade': null,
    'medicalConditions': null,
    'allergies': null,
    'previousExperience': null,
    'achievements': null,
    'enrollmentDate': '2026-07-30',
    'status': 'Active',
    'createdAt': '2026-07-30T09:58:08.277Z',
    'updatedAt': '2026-07-30T09:58:08.277Z',
    'User': {
      'id': 569,
      'name': 'Rahul Sharma',
      'email': 'rahul@example.com',
      'phone_number': '9876543210',
      'dob': null,
      'gender': null,
      'blood_group': null,
      'avatar': null,
      'status': 'Active',
      'join_date': '2026-07-27'
    }
  }
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    requests = <http.Request>[];
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  void serve(Object body, {int status = 200}) {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(body), status);
    }));
  }

  test('asks /students/me with the bearer token', () async {
    serve(_me);
    await UserRepository.instance.fetchMyStudentProfile();

    expect(requests.single.url.path, '/api/students/me');
    expect(requests.single.method, 'GET');
    expect(requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('maps the student record', () async {
    serve(_me);
    final student = await UserRepository.instance.fetchMyStudentProfile();

    expect(student, isNotNull);
    expect(student!.id, 45);
    expect(student.userId, 569);
    expect(student.enrollmentDate, '2026-07-30');
    expect(student.status, 'Active');
    expect(student.createdAt, '2026-07-30T09:58:08.277Z');
    expect(student.updatedAt, '2026-07-30T09:58:08.277Z');
  });

  test('maps the nested User the editor fills its fields from', () async {
    serve(_me);
    final user =
        (await UserRepository.instance.fetchMyStudentProfile())!.user!;

    expect(user.id, 569);
    expect(user.name, 'Rahul Sharma');
    expect(user.email, 'rahul@example.com');
    expect(user.phoneNumber, '9876543210');
    expect(user.joinDate, '2026-07-27');
    expect(user.status, 'Active');
  });

  test('null fields stay null instead of becoming "null" text', () async {
    serve(_me);
    final student = (await UserRepository.instance.fetchMyStudentProfile())!;

    expect(student.sportComplexId, isNull);
    expect(student.parentName, isNull);
    expect(student.schoolName, isNull);
    expect(student.medicalConditions, isNull);
    expect(student.user?.dob, isNull);
    expect(student.user?.gender, isNull);
    expect(student.user?.bloodGroup, isNull);
    expect(student.user?.avatar, isNull);
  });

  test('reads the optional student fields when they are filled in', () async {
    serve({
      'success': true,
      'data': {
        'id': 45,
        'userId': 569,
        'sportComplexId': 1,
        'parentName': 'Meera Sharma',
        'parentPhone': '9999999999',
        'parentEmail': 'meera@example.com',
        'schoolName': 'DAV',
        'grade': '8',
        'medicalConditions': 'Asthma',
        'allergies': 'Peanuts',
        'previousExperience': 'District level',
        'achievements': 'Gold 2025',
        'User': {
          'id': 569,
          'name': 'Rahul Sharma',
          'dob': '2003-03-30',
          'gender': 'Male',
          'blood_group': 'B-',
          'avatar': 'https://api.nahatasports.com/uploads/a.png'
        }
      }
    });

    final student = (await UserRepository.instance.fetchMyStudentProfile())!;

    expect(student.sportComplexId, 1);
    expect(student.parentName, 'Meera Sharma');
    expect(student.parentPhone, '9999999999');
    expect(student.schoolName, 'DAV');
    expect(student.grade, '8');
    expect(student.allergies, 'Peanuts');
    expect(student.achievements, 'Gold 2025');
    expect(student.user?.dob, '2003-03-30');
    expect(student.user?.bloodGroup, 'B-');
    expect(student.user?.avatar, 'https://api.nahatasports.com/uploads/a.png');
  });

  test('falls back to the account status when the record has none', () {
    final student = StudentProfile.fromJson(const {
      'id': 45,
      'User': {'status': 'Active'}
    });

    expect(student.status, isNull);
    expect(student.effectiveStatus, 'Active');
  });

  test('a non-student account yields null rather than an error', () async {
    serve({'success': false, 'message': 'Student not found'}, status: 404);

    expect(await UserRepository.instance.fetchMyStudentProfile(), isNull);
  });

  test('an empty payload yields null', () async {
    serve({'success': true, 'data': {}});

    expect(await UserRepository.instance.fetchMyStudentProfile(), isNull);
  });
}
