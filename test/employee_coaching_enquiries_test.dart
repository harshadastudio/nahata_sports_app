import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/features/employee/data/models/employee_mappers.dart';
import 'package:nahata_app/features/employee/data/repositories/employee_dashboard_repository_impl.dart';
import 'package:nahata_app/features/employee/domain/entities/employee_enquiry.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('EmployeeMappers.enquiry', () {
    test('reads sportId, coachId, isAllSports and enrolments', () {
      final enquiry = EmployeeMappers.enquiry({
        'id': 128,
        'name': 'Tanushree Sagar Lahoti',
        'email': 'swatilahoti83@gmail.com',
        'phone': '9987550997',
        'isAllSports': false,
        'sport': {'id': 19, 'name': 'Badminton'},
        'batch': {
          'id': 53,
          'name': 'Regular (Evening)',
          'fees': '3000.00',
          'maxStudents': 30,
          'currentStudents': 12,
        },
        'coach': {'id': 23, 'name': 'Dashrath Birhamane'},
        'status': 'Approved',
        'enrolments': [
          {
            'batchName': 'Regular (Evening)',
            'sportName': 'Badminton',
            'coachName': 'Dashrath Birhamane',
            'status': 'Active',
          },
        ],
      });

      expect(enquiry, isNotNull);
      expect(enquiry!.sportId, 19);
      expect(enquiry.coachId, 23);
      expect(enquiry.batchId, 53);
      expect(enquiry.isAllSports, isFalse);
      expect(enquiry.enrolments, hasLength(1));
      expect(enquiry.enrolments.first.displayBatch, 'Regular (Evening)');
      expect(
        enquiry.enrolments.first.detailLabel,
        'Badminton · Dashrath Birhamane',
      );
    });

    test('an all-sports enquiry has no enrolments yet', () {
      final enquiry = EmployeeMappers.enquiry({
        'id': 129,
        'name': 'Ravi Deshmukh',
        'isAllSports': true,
      });

      expect(enquiry!.isAllSports, isTrue);
      expect(enquiry.sportLabel, 'All sports');
      expect(enquiry.batchName, isEmpty);
      expect(enquiry.enrolments, isEmpty);
    });
  });

  group('EmployeeEnquiryDraft.toBody', () {
    test('a single-sport draft sends sportId/batchId/coachId, and strips '
        'non-digits from the phone', () {
      final body = const EmployeeEnquiryDraft(
        name: 'Ravi Deshmukh',
        email: 'ravi.deshmukh@example.com',
        phone: '(987) 654-3210',
        sportId: 19,
        batchId: 53,
        coachId: 23,
        message: 'Walk-in enquiry',
      ).toJson();

      expect(body['name'], 'Ravi Deshmukh');
      expect(body['phone'], '9876543210');
      expect(body['sportId'], 19);
      expect(body['batchId'], 53);
      expect(body['coachId'], 23);
      expect(body.containsKey('isAllSports'), isFalse);
    });

    test('an All Sports draft omits sport/batch/coach entirely', () {
      final body = const EmployeeEnquiryDraft(
        name: 'Undecided Walk-in',
        email: 'walkin@example.com',
        phone: '9876543210',
        isAllSports: true,
        sportId: 19,
        batchId: 53,
        coachId: 23,
      ).toJson();

      expect(body['isAllSports'], true);
      expect(body.containsKey('sportId'), isFalse);
      expect(body.containsKey('batchId'), isFalse);
      expect(body.containsKey('coachId'), isFalse);
    });

    test('a blank message is sent as null, not an empty string', () {
      final body = const EmployeeEnquiryDraft(
        name: 'A',
        email: 'a@example.com',
        phone: '9876543210',
        message: '   ',
      ).toJson();

      expect(body['message'], isNull);
    });
  });

  group('EmployeeDashboardRepositoryImpl — coaching enquiry writes', () {
    test('create posts to /coaching-enquiries/admin/create', () async {
      Uri? captured;
      Map<String, dynamic>? sentBody;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 130,
                'name': 'Ravi Deshmukh',
                'email': 'ravi.deshmukh@example.com',
                'phone': '9876543210',
                'status': 'Pending',
              },
            }),
            201,
          );
        }),
      );

      final repository = EmployeeDashboardRepositoryImpl();
      final created = await repository.createEnquiry(
        const EmployeeEnquiryDraft(
          name: 'Ravi Deshmukh',
          email: 'ravi.deshmukh@example.com',
          phone: '9876543210',
          batchId: 53,
        ),
      );

      expect(captured!.path, endsWith('/coaching-enquiries/admin/create'));
      expect(sentBody!['batchId'], 53);
      expect(created.enquiryId, 130);
    });

    test('update puts to /coaching-enquiries/admin/{id}', () async {
      Uri? captured;
      String? method;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          method = request.method;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 128, 'name': 'Updated Name', 'status': 'Pending'},
            }),
            200,
          );
        }),
      );

      final repository = EmployeeDashboardRepositoryImpl();
      await repository.updateEnquiry(
        128,
        const EmployeeEnquiryDraft(
          name: 'Updated Name',
          email: 'x@example.com',
          phone: '9876543210',
          batchId: 53,
        ),
      );

      expect(method, 'PUT');
      expect(captured!.path, endsWith('/coaching-enquiries/admin/128'));
    });

    test('changeStatus patches /coaching-enquiries/{id}/status, never Approved',
        () async {
      Uri? captured;
      Map<String, dynamic>? sentBody;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = EmployeeDashboardRepositoryImpl();
      await repository.setEnquiryStatus(128, 'Contacted');

      expect(captured!.path, endsWith('/coaching-enquiries/128/status'));
      expect(sentBody!['status'], 'Contacted');
      expect(EmployeeEnquiry.settableStatuses.contains('Approved'), isFalse);
    });

    test('delete hits DELETE /coaching-enquiries/{id}', () async {
      Uri? captured;
      String? method;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          method = request.method;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = EmployeeDashboardRepositoryImpl();
      await repository.deleteEnquiry(128);

      expect(method, 'DELETE');
      expect(captured!.path, endsWith('/coaching-enquiries/128'));
    });
  });
}
