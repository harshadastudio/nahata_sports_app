import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/event_pass_model.dart';
import 'package:nahata_app/repositories/event_booking_repository.dart';

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

/// Event 9 exactly as `GET /event-passes` returns it.
const Map<String, dynamic> _liveEvent = {
  'id': 9,
  'sportComplexId': 1,
  'title': 'Test Event',
  'status': 'Active',
  'customFields': [
    {
      'key': 'enter_parents_name',
      'type': 'text',
      'label': 'Enter Parents Name',
      'options': [],
      'required': true,
      'placeholder': 'Enter Parents Name',
    },
    {
      'key': '10th_grade',
      'type': 'text',
      'label': '10th Grade',
      'options': [],
      'required': true,
      'placeholder': '10th Grade',
    },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventCustomField parsing', () {
    test('reads the live Test Event payload', () {
      final pass =
          EventPassModel.fromJson(Map<String, dynamic>.from(_liveEvent));

      expect(pass.customFields, hasLength(2));

      final parent = pass.customFields.first;
      expect(parent.key, 'enter_parents_name');
      expect(parent.displayLabel, 'Enter Parents Name');
      expect(parent.required, isTrue);
      expect(parent.placeholder, 'Enter Parents Name');
      expect(parent.isChoice, isFalse);
    });

    test('an event that asks nothing has no fields', () {
      final pass = EventPassModel.fromJson({'id': 1, 'title': 'Plain'});
      expect(pass.customFields, isEmpty);
    });

    test('number and date types are recognised', () {
      final pass = EventPassModel.fromJson({
        'id': 7,
        'customFields': [
          {'key': 'child_age', 'type': 'number', 'label': 'Child Age'},
          {'key': 'date_of_birth', 'type': 'date', 'label': 'Date of Birth'},
        ],
      });

      expect(pass.customFields[0].isNumber, isTrue);
      expect(pass.customFields[1].isDate, isTrue);
    });

    test('options make a field a dropdown, in either shape', () {
      final pass = EventPassModel.fromJson({
        'id': 3,
        'customFields': [
          {
            'key': 'tshirt',
            'type': 'select',
            'options': ['S', 'M', 'L'],
          },
          {
            'key': 'meal',
            'type': 'radio',
            'options': [
              {'value': 'veg', 'label': 'Veg'},
              {'value': 'non_veg', 'label': 'Non-veg'},
            ],
          },
        ],
      });

      expect(pass.customFields[0].isChoice, isTrue);
      expect(pass.customFields[0].options, ['S', 'M', 'L']);
      expect(pass.customFields[1].options, ['veg', 'non_veg']);
    });

    test('a field with no label falls back to a readable key', () {
      final pass = EventPassModel.fromJson({
        'id': 3,
        'customFields': [
          {'key': 'child_name', 'type': 'text'},
        ],
      });

      expect(pass.customFields.single.displayLabel, 'Child name');
    });

    test('a field with no key is dropped, it could not be sent back', () {
      final pass = EventPassModel.fromJson({
        'id': 3,
        'customFields': [
          {'type': 'text', 'label': 'Orphan'},
          {'key': 'kept', 'type': 'text'},
        ],
      });

      expect(pass.customFields.single.key, 'kept');
    });

    test('an unknown type still renders as a plain text field', () {
      final pass = EventPassModel.fromJson({
        'id': 3,
        'customFields': [
          {'key': 'weird', 'type': 'colour-picker'},
        ],
      });

      final field = pass.customFields.single;
      expect(field.isChoice, isFalse);
      expect(field.isDate, isFalse);
      expect(field.isNumber, isFalse);
    });
  });

  group('createBooking sends the answers', () {
    late List<http.Request> requests;

    setUp(() async {
      _secureStore.clear();
      SharedPreferences.setMockInitialValues({});
      _mockSecureStorage();
      await TokenStorage.instance.clear();
      await TokenStorage.instance
          .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

      requests = <http.Request>[];
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'id': 6},
          }),
          200,
        );
      }));
    });

    tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

    Map<String, dynamic> lastBody() =>
        jsonDecode(requests.last.body) as Map<String, dynamic>;

    test('as the documented key/value list', () async {
      await EventBookingRepository.instance.createBooking(
        eventPassId: 9,
        slotId: 36,
        passes: 1,
        amount: 1,
        name: 'Rahul Sharma',
        email: 'rahul@example.com',
        customFieldValues: const {
          'enter_parents_name': 'xyz',
          '10th_grade': '10',
        },
      );

      expect(lastBody()['customFieldValues'], [
        {'key': 'enter_parents_name', 'value': 'xyz'},
        {'key': '10th_grade', 'value': '10'},
      ]);
    });

    test('an event that asks nothing sends no key at all', () async {
      await EventBookingRepository.instance.createBooking(
        eventPassId: 4,
        slotId: 17,
        passes: 2,
        amount: 400,
        customFieldValues: const {},
      );

      expect(lastBody().containsKey('customFieldValues'), isFalse);
    });

    test('omitting the answers entirely is still a valid booking', () async {
      await EventBookingRepository.instance.createBooking(
        eventPassId: 4,
        slotId: 17,
        passes: 2,
        amount: 400,
      );

      expect(lastBody().containsKey('customFieldValues'), isFalse);
      expect(lastBody()['eventPassId'], 4);
    });
  });
}
