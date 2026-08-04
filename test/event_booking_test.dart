import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/config/api_config.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
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

  Map<String, dynamic> lastBody() =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;

  Future<EventBookingResult> create({String? couponCode, int? venue}) {
    return EventBookingRepository.instance.createBooking(
      eventPassId: 4,
      slotId: 17,
      passes: 2,
      amount: 400,
      name: 'Admin User',
      email: 'admin@nahatasports.com',
      couponCode: couponCode,
      sportComplexId: venue,
    );
  }

  test('posts the booking to the configured path', () async {
    serve({
      'success': true,
      'data': {'id': 19}
    });

    await create();

    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api${ApiEndpoints.eventBookingCreate}');
    expect(requests.single.headers['Authorization'], 'Bearer access-1');
  });

  test('sends the booking details', () async {
    serve({
      'success': true,
      'data': {'id': 19}
    });

    await create(couponCode: 'NAHATA10', venue: 2);

    expect(lastBody(), {
      'eventPassId': 4,
      'slotId': 17,
      'numberOfPasses': 2,
      'totalAmount': 400,
      'name': 'Admin User',
      'email': 'admin@nahatasports.com',
      'couponCode': 'NAHATA10',
      'sportComplexId': 2,
    });
  });

  test('leaves out the coupon and venue when there are none', () async {
    serve({
      'success': true,
      'data': {'id': 19}
    });

    await create();

    expect(lastBody().containsKey('couponCode'), isFalse);
    expect(lastBody().containsKey('sportComplexId'), isFalse);
  });

  group('reads the new booking id from', () {
    test('data.id — the id create-order then refers to', () async {
      serve({
        'success': true,
        'data': {'id': 19, 'status': 'Pending'}
      });

      final result = await create();

      expect(result.isOk, isTrue);
      expect(result.bookingId, 19);
      expect(result.data?['status'], 'Pending');
    });

    test('data.booking.id', () async {
      serve({
        'success': true,
        'data': {
          'booking': {'id': 19}
        }
      });

      expect((await create()).bookingId, 19);
    });

    test('data.bookings[0].id — the shape facility bookings use', () async {
      serve({
        'success': true,
        'data': {
          'bookings': [
            {'id': 19}
          ]
        }
      });

      expect((await create()).bookingId, 19);
    });

    test('a string id', () async {
      serve({
        'success': true,
        'data': {'bookingId': '19'}
      });

      expect((await create()).bookingId, 19);
    });
  });

  group('GET /event-passes/bookings/my', () {
    /// Verbatim from the live endpoint.
    const myBookingsJson = {
      'success': true,
      'message': 'Your bookings retrieved successfully',
      'data': [
        {
          'id': 27,
          'eventPassId': 1,
          'slotId': 20,
          'userId': 569,
          'name': 'Rahul Sharma',
          'email': 'rahul@example.com',
          'numberOfPasses': 1,
          'totalAmount': '200.00',
          'couponCode': null,
          'discountAmount': '0.00',
          'originalAmount': null,
          'status': 'Pending',
          'qrCode':
              'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=EVTPASS-2026-000027&format=png&margin=10',
          'razorpayOrderId': null,
          'razorpayPaymentId': null,
          'createdAt': '2026-07-30T09:03:16.278Z',
          'updatedAt': '2026-07-30T09:03:16.287Z',
          'event': {
            'id': 1,
            'title': 'Event 1',
            'image':
                'https://res.cloudinary.com/dumqxrojz/image/upload/v1778475328/nahata-sports/event-passes/msiojrkyyqil6aul9rfn.jpg'
          },
          'slot': {
            'id': 20,
            'name': 'Phase 1',
            'date': '2026-07-15',
            'passType': null,
            'price': '200.00',
            'startTime': '16:24:00',
            'endTime': '19:32:00'
          },
          'individualPasses': [
            {
              'id': 27,
              'passCode': 'EVTPASS-2026-000027',
              'qrCode':
                  'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=EVTPASS-2026-000027&format=png&margin=10',
              'maxPersons': 1,
              'scannedInCount': 0,
              'scannedOutCount': 0,
              'scanStatus': 'NotScanned',
              'scannedInAt': null,
              'scannedOutAt': null,
              'holderName': 'Rahul Sharma',
              'holderEmail': 'rahul@example.com',
              'isValid': true,
              'members': []
            }
          ]
        }
      ]
    };

    test('asks the right endpoint with the bearer token', () async {
      serve(myBookingsJson);
      await EventBookingRepository.instance.fetchMyBookings();

      expect(requests.single.url.path, '/api/event-passes/bookings/my');
      expect(requests.single.method, 'GET');
      expect(requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('maps the booking, its event and its slot', () async {
      serve(myBookingsJson);
      final booking =
          (await EventBookingRepository.instance.fetchMyBookings()).single;

      expect(booking.id, 27);
      expect(booking.eventPassId, 1);
      expect(booking.slotId, 20);
      expect(booking.name, 'Rahul Sharma');
      expect(booking.numberOfPasses, 1);
      expect(booking.totalValue, 200);
      expect(booking.discountValue, 0);
      expect(booking.couponCode, isNull);
      expect(booking.status, 'Pending');
      expect(booking.isPaid, isFalse);
      expect(booking.event?.title, 'Event 1');
      expect(booking.slot?.name, 'Phase 1');
      expect(booking.slot?.date, '2026-07-15');
      expect(booking.slot?.startTime, '16:24:00');
      expect(booking.slot?.passType, isNull);
    });

    test('maps the individual passes', () async {
      serve(myBookingsJson);
      final booking =
          (await EventBookingRepository.instance.fetchMyBookings()).single;
      final pass = booking.individualPasses.single;

      expect(pass.passCode, 'EVTPASS-2026-000027');
      expect(pass.qrCode, contains('EVTPASS-2026-000027'));
      expect(pass.scanStatus, 'NotScanned');
      expect(pass.isScanned, isFalse);
      expect(pass.isValid, isTrue);
      expect(pass.holderName, 'Rahul Sharma');
      expect(booking.passCode, 'EVTPASS-2026-000027');
      expect(booking.displayQrCode, contains('EVTPASS-2026-000027'));
    });

    test('flattens into exactly the keys the pass screen reads', () async {
      serve(myBookingsJson);
      final booking =
          (await EventBookingRepository.instance.fetchMyBookings()).single;

      final map = booking.toViewPassMap();
      expect(map['tournament_title'], 'Event 1');
      expect(map['slot_name'], 'Phase 1');
      expect(map['pass_date'], '2026-07-15');
      expect(map['start_time'], '16:24:00');
      expect(map['end_time'], '19:32:00');
      expect(map['members_count'], '1');
      expect(map['pass_price'], '200.00');
      expect(map['qr_code'], contains('EVTPASS-2026-000027'));
      expect(map['pass_code'], 'EVTPASS-2026-000027');
    });

    test('newest booking comes first', () async {
      serve({
        'success': true,
        'data': [
          {'id': 27, 'createdAt': '2026-07-01T09:03:16.278Z'},
          {'id': 31, 'createdAt': '2026-07-30T09:03:16.278Z'},
          {'id': 29, 'createdAt': '2026-07-15T09:03:16.278Z'},
        ]
      });

      final bookings = await EventBookingRepository.instance.fetchMyBookings();
      expect(bookings.map((b) => b.id), [31, 29, 27]);
    });

    test('finds a single booking by id', () async {
      serve(myBookingsJson);

      expect((await EventBookingRepository.instance.fetchMyBooking(27))?.id, 27);
      expect(await EventBookingRepository.instance.fetchMyBooking(99), isNull);
    });

    test('no bookings yet is not an error', () async {
      serve({'success': true, 'data': []});

      expect(await EventBookingRepository.instance.fetchMyBookings(), isEmpty);
    });
  });

  group('failures keep the user out of checkout', () {
    test('a rejected booking surfaces the server message', () async {
      serve({'success': false, 'message': 'Slot is sold out'}, status: 400);

      final result = await create();

      expect(result.isOk, isFalse);
      expect(result.bookingId, isNull);
      expect(result.message, 'Slot is sold out');
    });

    test('a 404 on the booking path fails closed', () async {
      // If the configured path is wrong, nothing must reach Razorpay.
      serve({'success': false, 'message': 'Not Found'}, status: 404);

      expect((await create()).isOk, isFalse);
    });

    test('a success with no id anywhere is treated as a failure', () async {
      serve({
        'success': true,
        'data': {'status': 'Pending'}
      });

      expect((await create()).isOk, isFalse);
    });
  });
}
