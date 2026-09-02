import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/config/api_config.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/enrollment_model.dart';
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

/// Pass 54 verbatim from `GET /fees/my`, including the quirks the live payload
/// actually carries: empty `startTime`/`endTime`, and a `validTill` that falls
/// before the day the pass was approved.
const Map<String, dynamic> _pass54 = {
  'id': 54,
  'passCode': 'GATEPASS-2026-000054',
  'qrCode':
      'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=GATEPASS-2026-000054&format=png&margin=10',
  'studentName': 'Shiphan Pathan',
  'studentPhone': '9307556133',
  'bloodGroup': 'O+',
  'dob': '2000-03-17',
  'batchId': 32,
  'batchName': 'Regular (Evening)',
  'sportName': 'Basketball',
  'sportImage':
      'https://api.nahatasports.com/uploads/nahata-sports/sports/sports-1783573708239-630572633.png',
  'coachName': 'Dashrath Birhamane',
  'amountPaid': '1500.00',
  'batchFee': '1500.00',
  'paymentStatus': 'Paid',
  'approvalStatus': 'Approved',
  'enrollmentDate': '2026-08-24',
  'validTill': '2026-07-31',
  'approvedAt': '2026-08-24T09:54:54.125Z',
  'status': 'Active',
  'notes': '',
  'batchDays': 'Monday,Tuesday,Wednesday,Thursday,Friday',
  'startTime': '',
  'endTime': '',
};

/// Pass 42, whose batch name carries trailing whitespace on the wire.
const Map<String, dynamic> _pass42 = {
  'id': 42,
  'passCode': 'GATEPASS-2026-000042',
  'batchName': '3 DAYS (Morning)   ',
  'sportName': 'Badminton',
  'coachName': 'Sudhanshu Medsikar',
  'amountPaid': '2500.00',
  'paymentStatus': 'Paid',
  'approvalStatus': 'Approved',
  'enrollmentDate': '2026-07-28',
  'validTill': '2026-07-31',
  'status': 'Active',
  'notes': '',
  'batchDays': 'Monday,Tuesday,Wednesday,Thursday,Friday',
  'startTime': '',
  'endTime': '',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GatePassModel parses the live /fees/my row', () {
    final pass = GatePassModel.fromJson(Map<String, dynamic>.from(_pass54));

    test('every field on the wire is read', () {
      expect(pass.id, 54);
      expect(pass.passCode, 'GATEPASS-2026-000054');
      expect(pass.qrCode, startsWith('https://api.qrserver.com/'));
      expect(pass.studentName, 'Shiphan Pathan');
      expect(pass.studentPhone, '9307556133');
      expect(pass.bloodGroup, 'O+');
      expect(pass.dob, '2000-03-17');
      expect(pass.batchId, 32);
      expect(pass.batchName, 'Regular (Evening)');
      expect(pass.sportName, 'Basketball');
      expect(pass.sportImage, contains('/uploads/nahata-sports/sports/'));
      expect(pass.coachName, 'Dashrath Birhamane');
      expect(pass.amountPaid, '1500.00');
      expect(pass.batchFee, '1500.00');
      expect(pass.paymentStatus, 'Paid');
      expect(pass.approvalStatus, 'Approved');
      expect(pass.enrollmentDate, '2026-08-24');
      expect(pass.validTill, '2026-07-31');
      expect(pass.approvedAt, '2026-08-24T09:54:54.125Z');
      expect(pass.status, 'Active');
      expect(pass.batchDays, 'Monday,Tuesday,Wednesday,Thursday,Friday');
    });

    test('the card title joins sport and batch', () {
      expect(pass.title, 'Basketball · Regular (Evening)');
    });

    test('the days line is spaced for reading', () {
      expect(pass.daysLabel,
          'Monday, Tuesday, Wednesday, Thursday, Friday');
    });

    test('empty times produce no label, not a stray separator', () {
      // startTime and endTime both arrive as "" on every row today.
      expect(pass.sessionLabel, isEmpty);
    });

    test('an empty note is absent rather than blank', () {
      expect(pass.notes, isNull);
    });

    test('a batch name is trimmed of the wire whitespace', () {
      final other = GatePassModel.fromJson(Map<String, dynamic>.from(_pass42));
      expect(other.batchName, '3 DAYS (Morning)');
      expect(other.title, 'Badminton · 3 DAYS (Morning)');
    });
  });

  group('a pass is only usable when the gate would accept it', () {
    Map<String, dynamic> withValidTill(String? validTill) => {
          ..._pass54,
          if (validTill == null) 'validTill': null else 'validTill': validTill,
        };

    test('an expired pass is not usable, however it was paid', () {
      // Every row the live endpoint returns today is in this state: approved
      // and paid, but with validTill already in the past.
      final pass = GatePassModel.fromJson(withValidTill('2026-07-31'));

      expect(pass.approvalStatus, 'Approved');
      expect(pass.paymentStatus, 'Paid');
      expect(pass.isValid, isFalse);
      expect(pass.isUsable, isFalse);
      expect(pass.statusLabel, 'EXPIRED');
    });

    test('a pass valid well into the future is usable', () {
      final pass = GatePassModel.fromJson(withValidTill('2099-12-31'));

      expect(pass.isValid, isTrue);
      expect(pass.isUsable, isTrue);
      expect(pass.statusLabel, 'ACTIVE PASS');
    });

    test('an open-ended pass never expires', () {
      final pass = GatePassModel.fromJson(withValidTill(null));
      expect(pass.isValid, isTrue);
    });

    test('an unpaid pass is held back even while in date', () {
      final pass = GatePassModel.fromJson({
        ..._pass54,
        'validTill': '2099-12-31',
        'paymentStatus': 'Pending',
      });

      expect(pass.isUsable, isFalse);
      expect(pass.statusLabel, 'PAYMENT PENDING');
    });

    test('an unapproved pass is held back too', () {
      final pass = GatePassModel.fromJson({
        ..._pass54,
        'validTill': '2099-12-31',
        'approvalStatus': 'Rejected',
      });

      expect(pass.isUsable, isFalse);
      expect(pass.statusLabel, 'REJECTED');
    });
  });

  test('the pass card reads a flat coaching-shaped map', () {
    final map = GatePassModel.fromJson(Map<String, dynamic>.from(_pass54))
        .toPassMap();

    // `pass_kind` is what separates a coaching pass from a court booking in
    // the same carousel.
    expect(map['pass_kind'], 'coaching');
    expect(map['pass_code'], 'GATEPASS-2026-000054');
    expect(map['title'], 'Basketball · Regular (Evening)');
    expect(map['coach_name'], 'Dashrath Birhamane');
    expect(map['blood_group'], 'O+');
    expect(map['amount_paid'], '1500.00');
    expect(map['is_usable'], isFalse);
    expect(map['status_label'], 'EXPIRED');
  });

  group('GET /fees/my', () {
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

    test('asks the documented path with the bearer token', () async {
      serve({'success': true, 'data': []});

      await UserRepository.instance.fetchMyGatePasses();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api${ApiEndpoints.myGatePasses}');
      expect(requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('returns every pass, expired ones included', () async {
      // The list is not filtered: a student needs to see a pass that has run
      // out, labelled as such, rather than an empty screen.
      serve({
        'success': true,
        'data': [_pass54, _pass42],
      });

      final passes = await UserRepository.instance.fetchMyGatePasses();

      expect(passes, hasLength(2));
      expect(passes.map((p) => p.passCode),
          ['GATEPASS-2026-000054', 'GATEPASS-2026-000042']);
      expect(passes.every((p) => p.isUsable), isFalse);
    });

    test('a student with no passes gets an empty list, not an error', () async {
      serve({'success': true, 'data': []});
      expect(await UserRepository.instance.fetchMyGatePasses(), isEmpty);
    });
  });
}
