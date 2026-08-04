import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/bottombar/event.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/services/selected_ground.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/event_pass_model.dart';
import 'package:nahata_app/repositories/event_repository.dart';

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

/// Both events, verbatim from `/event-passes?status=Active&page=1&limit=50`.
const String _allEventsJson = '''
{
  "success": true,
  "message": "Event passes retrieved successfully",
  "data": [
    {
      "id": 4,
      "sportComplexId": 2,
      "title": "Holi Event",
      "description": "lorem Ipsum is simply dummy text of the printing and typesetting industry.",
      "image": "https://api.nahatasports.com/uploads/nahata-sports/event-passes/event-passes-1783511580828-101484723.jpg",
      "faqs": [],
      "status": "Active",
      "createdAt": "2026-07-08T11:29:38.985Z",
      "updatedAt": "2026-07-08T11:53:05.510Z",
      "slots": [
        {"id": 17, "eventPassId": 4, "name": "Phase1", "date": "2026-07-17",
         "price": "200.00", "passType": null, "startTime": "16:59:00",
         "endTime": "17:59:00", "status": "Active"}
      ],
      "sportComplex": {"id": 2, "name": "Gangadham Chowk"}
    },
    {
      "id": 1,
      "sportComplexId": 1,
      "title": "Event 1",
      "description": "lorem Ipsum is simply dummy text of the printing and typesetting industry.",
      "image": "https://res.cloudinary.com/dumqxrojz/image/upload/v1778475328/nahata-sports/event-passes/msiojrkyyqil6aul9rfn.jpg",
      "faqs": [
        {"answer": "FAQ test", "question": "FAQ"},
        {"answer": "FAQ test", "question": "FAQ 2"}
      ],
      "status": "Active",
      "createdAt": "2026-05-04T10:03:07.616Z",
      "updatedAt": "2026-07-13T06:24:35.379Z",
      "slots": [
        {"id": 20, "eventPassId": 1, "name": "Phase 1", "date": "2026-07-15",
         "price": "200.00", "passType": null, "startTime": "16:24:00",
         "endTime": "19:32:00", "status": "Active"}
      ],
      "sportComplex": {"id": 1, "name": "Sinhagad Road"}
    }
  ],
  "pagination": {"currentPage": 1, "totalPages": 1, "totalItems": 2, "itemsPerPage": 50}
}
''';

/// The `sportComplexId=1` variant — only Event 1.
const String _sinhagadEventsJson = '''
{
  "success": true,
  "data": [
    {
      "id": 1,
      "sportComplexId": 1,
      "title": "Event 1",
      "description": "lorem Ipsum",
      "image": "https://cdn/event1.jpg",
      "faqs": [{"answer": "FAQ test", "question": "FAQ"}],
      "status": "Active",
      "slots": [
        {"id": 20, "eventPassId": 1, "name": "Phase 1", "date": "2026-07-15",
         "price": "200.00", "startTime": "16:24:00", "endTime": "19:32:00",
         "status": "Active"}
      ],
      "sportComplex": {"id": 1, "name": "Sinhagad Road"}
    }
  ],
  "pagination": {"currentPage": 1, "totalPages": 1, "totalItems": 1, "itemsPerPage": 50}
}
''';

const String _complexesJson = '''
{"success": true, "data": {"sportsComplexes": [
  {"id": 1, "name": "Sinhagad Road"},
  {"id": 2, "name": "Gangadham Chowk"}
]}}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Uri> requests;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    EventRepository.instance.invalidateCache();
    await SelectedGround.instance.clear();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    requests = <Uri>[];
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  void serve() {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/sports-complexes')) {
        return http.Response(_complexesJson, 200);
      }
      final complexId = request.url.queryParameters['sportComplexId'];
      if (complexId == '1') return http.Response(_sinhagadEventsJson, 200);
      return http.Response(_allEventsJson, 200);
    }));
  }

  Uri lastEventsCall() =>
      requests.lastWhere((u) => u.path.endsWith('/event-passes'));

  group('parsing', () {
    test('reads the documented query parameters', () async {
      serve();
      await EventRepository.instance.fetchEventPassPage();

      final call = lastEventsCall();
      expect(call.path, '/api/event-passes');
      expect(call.queryParameters['status'], 'Active');
      expect(call.queryParameters['page'], '1');
      expect(call.queryParameters['limit'], '50');
      expect(call.queryParameters.containsKey('sportComplexId'), isFalse);
    });

    test('reads pagination from the sibling `pagination` object', () async {
      serve();
      final page = await EventRepository.instance.fetchEventPassPage();

      expect(page.events, hasLength(2));
      expect(page.currentPage, 1);
      expect(page.totalPages, 1);
      expect(page.totalItems, 2);
      expect(page.itemsPerPage, 50);
      expect(page.hasMore, isFalse);
    });

    test('maps every event field', () async {
      serve();
      final page = await EventRepository.instance.fetchEventPassPage();
      final holi = page.events.firstWhere((e) => e.id == 4);

      expect(holi.title, 'Holi Event');
      expect(holi.sportComplexId, 2);
      expect(holi.venueName, 'Gangadham Chowk');
      expect(holi.status, 'Active');
      expect(holi.isActive, isTrue);
      expect(holi.image, contains('event-passes-1783511580828'));
      expect(holi.faqs, isEmpty);
    });

    test('maps the nested slots', () async {
      serve();
      final page = await EventRepository.instance.fetchEventPassPage();
      final slot = page.events.firstWhere((e) => e.id == 4).slots.single;

      expect(slot.id, 17);
      expect(slot.eventPassId, 4);
      expect(slot.name, 'Phase1');
      expect(slot.date, '2026-07-17');
      expect(slot.price, '200.00');
      expect(slot.priceValue, 200.0);
      expect(slot.passType, isNull);
      expect(slot.startTime, '16:59:00');
      expect(slot.endTime, '17:59:00');
      expect(slot.isActive, isTrue);
    });

    test('maps the FAQ list', () async {
      serve();
      final page = await EventRepository.instance.fetchEventPassPage();
      final event1 = page.events.firstWhere((e) => e.id == 1);

      expect(event1.faqs, hasLength(2));
      expect(event1.faqs.first.question, 'FAQ');
      expect(event1.faqs.first.answer, 'FAQ test');
    });

    test('an empty or malformed payload yields no events', () async {
      ApiClient.instance.overrideHttpClient(MockClient((_) async =>
          http.Response(jsonEncode({'success': true, 'data': null}), 200)));

      final page = await EventRepository.instance.fetchEventPassPage();
      expect(page.events, isEmpty);
    });

    test('lowestPrice and earliestSlotDate are derived from active slots',
        () async {
      final pass = EventPassModel.fromJson(const {
        'id': 9,
        'slots': [
          {'id': 1, 'date': '2026-09-01', 'price': '500.00', 'status': 'Active'},
          {'id': 2, 'date': '2026-08-01', 'price': '300.00', 'status': 'Active'},
          {'id': 3, 'date': '2026-01-01', 'price': '10.00', 'status': 'Inactive'},
        ]
      });

      expect(pass.activeSlots, hasLength(2));
      expect(pass.lowestPrice, 300.0);
      expect(pass.earliestSlotDate, DateTime(2026, 8, 1));
    });
  });

  group('venue filtering', () {
    test('sends sportComplexId for the selected venue', () async {
      serve();
      await SelectedGround.instance.save('Sinhagad Road', id: 1);

      final events = await fetchEvents(status: 'active');

      expect(lastEventsCall().queryParameters['sportComplexId'], '1');
      expect(events, hasLength(1));
      expect(events.single.title, 'Event 1');
    });

    test('resolves the venue id from its name when only the name is known',
        () async {
      serve();
      // Saved without an id — as the coaching flow does.
      await SelectedGround.instance.save('Sinhagad Road');

      final events = await fetchEvents(status: 'active');

      // It looked the id up from /sports-complexes…
      expect(requests.any((u) => u.path.endsWith('/sports-complexes')), isTrue);
      expect(lastEventsCall().queryParameters['sportComplexId'], '1');
      expect(events.single.title, 'Event 1');

      // …and cached it back onto the selection.
      expect(await SelectedGround.instance.readId(), 1);
    });

    test('lists every venue when none is selected', () async {
      serve();

      final events = await fetchEvents(status: 'active');

      expect(lastEventsCall().queryParameters.containsKey('sportComplexId'),
          isFalse);
      expect(events, hasLength(2));
    });

    test('lists the venues the picker offers, in API order', () async {
      serve();
      final venues = await EventRepository.instance.fetchVenues();

      expect(venues.map((v) => v.name), ['Sinhagad Road', 'Gangadham Chowk']);
      expect(venues.map((v) => v.id), [1, 2]);
    });

    test('an explicit venue overrides the saved selection', () async {
      serve();
      await SelectedGround.instance.save('Gangadham Chowk', id: 2);

      // What the picker sends for "Sinhagad Road".
      final events = await fetchEvents(
        status: 'active',
        sportComplexId: 1,
        filterBySelectedVenue: false,
      );

      expect(lastEventsCall().queryParameters['sportComplexId'], '1');
      expect(events.single.title, 'Event 1');
    });

    test('"All complexes" sends no venue filter even when one is saved',
        () async {
      serve();
      await SelectedGround.instance.save('Sinhagad Road', id: 1);

      // What the picker sends for "All complexes".
      final events = await fetchEvents(
        status: 'active',
        filterBySelectedVenue: false,
      );

      expect(lastEventsCall().queryParameters.containsKey('sportComplexId'),
          isFalse);
      expect(events, hasLength(2));
    });

    test('an unknown venue name falls back to showing everything', () async {
      serve();
      await SelectedGround.instance.save('Nowhere Ground');

      final events = await fetchEvents(status: 'active');

      expect(lastEventsCall().queryParameters.containsKey('sportComplexId'),
          isFalse);
      expect(events, hasLength(2));
    });
  });

  group('tabs', () {
    /// Both sample events are dated 2026-07; "upcoming" depends on today.
    test('"upcoming" keeps only events with a slot today or later', () async {
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 1,
                'title': 'Long past',
                'status': 'Active',
                'slots': [
                  {'id': 1, 'date': '2020-01-01', 'price': '100.00',
                   'status': 'Active'}
                ],
                'sportComplex': {'id': 1, 'name': 'Sinhagad Road'}
              },
              {
                'id': 2,
                'title': 'Far future',
                'status': 'Active',
                'slots': [
                  {'id': 2, 'date': '2099-01-01', 'price': '100.00',
                   'status': 'Active'}
                ],
                'sportComplex': {'id': 1, 'name': 'Sinhagad Road'}
              },
            ],
            'pagination': {'currentPage': 1, 'totalPages': 1}
          }),
          200,
        );
      }));

      final active = await fetchEvents(status: 'active');
      expect(active.map((e) => e.title), ['Long past', 'Far future']);

      final upcoming = await fetchEvents(status: 'upcoming');
      expect(upcoming.map((e) => e.title), ['Far future']);
    });
  });

  group('view model', () {
    test('carries slots through so the details page needs no second call',
        () async {
      serve();
      final events = await fetchEvents(status: 'active');
      final holi = events.firstWhere((e) => e.title == 'Holi Event');

      expect(holi.slots, hasLength(1));
      // Exactly the keys the booking UI reads.
      expect(holi.slots.single, {
        'id': 17,
        'name': 'Phase1',
        'date': '2026-07-17',
        'price': '200.00',
        'pass_type': '',
        'start': '16:59:00',
        'end': '17:59:00',
      });
    });

    test('uses the API image URL as-is', () async {
      serve();
      final events = await fetchEvents(status: 'active');

      // The old code prefixed every path with nahatasports.com, which would
      // corrupt these absolute URLs.
      expect(events.firstWhere((e) => e.title == 'Event 1').image,
          startsWith('https://res.cloudinary.com/'));
      expect(events.every((e) => e.image.startsWith('http')), isTrue);
    });

    test('location comes from the nested sportComplex', () async {
      serve();
      final events = await fetchEvents(status: 'active');

      expect(events.firstWhere((e) => e.title == 'Holi Event').location,
          'Gangadham Chowk');
      expect(events.firstWhere((e) => e.title == 'Event 1').location,
          'Sinhagad Road');
    });

    test('plain descriptions survive the formatter', () async {
      serve();
      final events = await fetchEvents(status: 'active');
      final description =
          events.firstWhere((e) => e.title == 'Holi Event').formattedDescription;

      // No "About The Event:" style labels here — the raw text must still show.
      expect(description, isNotEmpty);
      expect(description, contains('lorem Ipsum'));
    });

    test('labelled descriptions still get the formatted layout', () {
      final event = EventModel(
        id: '1',
        title: 't',
        image: '',
        location: 'v',
        description: 'About The Event: A great show. Age Group: 5+',
      );

      expect(event.formattedDescription, contains('A great show'));
      expect(event.formattedDescription, contains('Age Group: 5+'));
    });
  });
}
