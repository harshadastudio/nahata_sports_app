import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/court_booking_model.dart';
import 'package:nahata_app/repositories/court_booking_repository.dart';

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

/// Two entries from the live `/courts/bookings/my` response — one Confirmed
/// and paid, one Pending.
const Map<String, dynamic> _myBookings = {
  'success': true,
  'data': [
    {
      'id': 71,
      'date': '2026-08-02',
      'startTime': '05:00:00',
      'endTime': '06:00:00',
      'bookingStatus': 'Confirmed',
      'paymentStatus': 'Paid',
      'totalAmount': '300.00',
      'bookingSource': 'Website',
      'passCode': 'BOOK-2026-000071',
      'qrCode':
          'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=BOOK-2026-000071&format=png&margin=10',
      'maxPersons': 2,
      'scannedInCount': 0,
      'scannedOutCount': 0,
      'scanStatus': 'NotScanned',
      'scannedInAt': null,
      'scannedOutAt': null,
      'transactionId': 'pay_TIVKamk7ZcDnNs',
      'couponCode': null,
      'discountAmount': '0.00',
      'notes': null,
      'createdAt': '2026-07-27T11:05:43.202Z',
      'court': {
        'id': 10,
        'sportComplexId': 1,
        'sportId': 26,
        'name': 'Basketball Court',
        'surfaceType': 'Hard',
        'hourlyRate': '300.00',
        'status': 'Active',
        'SportComplex': {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'}
      },
      'sport': {
        'id': 26,
        'name': 'Basketball',
        'image':
            'https://api.nahatasports.com/uploads/nahata-sports/sports/sports-1783573708239-630572633.png'
      },
      'members': []
    },
    {
      'id': 63,
      'date': '2026-08-01',
      'startTime': '20:00:00',
      'endTime': '21:00:00',
      'bookingStatus': 'Pending',
      'paymentStatus': 'Pending',
      'totalAmount': '0.00',
      'passCode': 'BOOK-2026-000063',
      'qrCode':
          'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=BOOK-2026-000063&format=png&margin=10',
      'maxPersons': 1,
      'scanStatus': 'NotScanned',
      'transactionId': null,
      'couponCode': null,
      'discountAmount': '0.00',
      'createdAt': '2026-07-27T08:51:18.241Z',
      'court': {
        'id': 6,
        'sportComplexId': 1,
        'sportId': 19,
        'name': 'Badminton Court 1',
        'SportComplex': {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'}
      },
      'sport': {'id': 19, 'name': 'Badminton', 'image': null},
      'members': []
    }
  ],
  'pagination': {'currentPage': 1, 'totalPages': 1, 'totalItems': 12}
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

  test('asks for the first page with the bearer token', () async {
    serve(_myBookings);
    await CourtBookingRepository.instance.fetchMyBookings();

    expect(requests.first.url.path, '/api/courts/bookings/my');
    expect(requests.first.url.queryParameters['page'], '1');
    expect(requests.first.url.queryParameters['limit'], '20');
    expect(requests.first.headers['Authorization'], 'Bearer access-1');
  });

  test('maps a confirmed booking with its court, venue and sport', () async {
    serve(_myBookings);
    final booking = (await CourtBookingRepository.instance.fetchMyBookings())
        .firstWhere((b) => b.id == 71);

    expect(booking.date, '2026-08-02');
    expect(booking.startTime, '05:00:00');
    expect(booking.endTime, '06:00:00');
    expect(booking.bookingStatus, 'Confirmed');
    expect(booking.paymentStatus, 'Paid');
    expect(booking.isPaid, isTrue);
    expect(booking.isConfirmed, isTrue);
    expect(booking.totalValue, 300);
    expect(booking.passCode, 'BOOK-2026-000071');
    expect(booking.qrCode, contains('BOOK-2026-000071'));
    expect(booking.maxPersons, 2);
    expect(booking.transactionId, 'pay_TIVKamk7ZcDnNs');
    expect(booking.isScanned, isFalse);
    expect(booking.court?.name, 'Basketball Court');
    expect(booking.court?.complex?.name, 'Sinhagad Road');
    expect(booking.court?.complex?.city, 'Pune');
    expect(booking.sport?.name, 'Basketball');
  });

  test('a pending booking is neither paid nor confirmed', () async {
    serve(_myBookings);
    final booking = (await CourtBookingRepository.instance.fetchMyBookings())
        .firstWhere((b) => b.id == 63);

    expect(booking.isPaid, isFalse);
    expect(booking.isConfirmed, isFalse);
    expect(booking.totalValue, 0);
    expect(booking.transactionId, isNull);
    expect(booking.sport?.image, isNull);
  });

  test('flattens into the keys the pass card reads', () async {
    serve(_myBookings);
    final map = (await CourtBookingRepository.instance.fetchMyBookings())
        .first
        .toPassMap();

    expect(map['sport_name'], 'Basketball');
    expect(map['court_name'], 'Basketball Court');
    expect(map['venue_name'], 'Sinhagad Road');
    expect(map['pass_date'], '2026-08-02');
    expect(map['start_time'], '05:00:00');
    expect(map['end_time'], '06:00:00');
    expect(map['pass_code'], 'BOOK-2026-000071');
    expect(map['qr_code'], contains('BOOK-2026-000071'));
    expect(map['status'], 'Confirmed');
    expect(map['payment_status'], 'Paid');
  });

  test('the QR url is absolute, so it must not be rewritten', () async {
    serve(_myBookings);
    final qr = (await CourtBookingRepository.instance.fetchMyBookings())
        .first
        .qrCode!;

    expect(qr, startsWith('https://api.qrserver.com/'));
    expect(Uri.parse(qr).host, 'api.qrserver.com');
  });

  test('keeps the order the API returns', () async {
    serve(_myBookings);
    final bookings = await CourtBookingRepository.instance.fetchMyBookings();

    expect(bookings.map((b) => b.id), [71, 63]);
  });

  test('follows pagination', () async {
    var call = 0;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request);
      call++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {'id': call, 'passCode': 'BOOK-$call'}
          ],
          'pagination': {
            'currentPage': call,
            'totalPages': 3,
            'totalItems': 3
          }
        }),
        200,
      );
    }));

    final bookings = await CourtBookingRepository.instance.fetchMyBookings();

    expect(bookings.map((b) => b.id), [1, 2, 3]);
    expect(requests.map((r) => r.url.queryParameters['page']), ['1', '2', '3']);
  });

  test('a failure leaves the screen empty rather than throwing', () async {
    serve({'success': false, 'message': 'Server error'}, status: 500);

    expect(await CourtBookingRepository.instance.fetchMyBookings(), isEmpty);
  });

  test('no bookings yet is not an error', () async {
    serve({
      'success': true,
      'data': [],
      'pagination': {'currentPage': 1, 'totalPages': 1, 'totalItems': 0}
    });

    expect(await CourtBookingRepository.instance.fetchMyBookings(), isEmpty);
  });

  test('an upcoming booking is recognised by its date', () {
    final past = CourtBooking.fromJson(const {'id': 1, 'date': '2020-01-01'});
    final future = CourtBooking.fromJson(const {'id': 2, 'date': '2099-01-01'});

    expect(past.isUpcoming, isFalse);
    expect(future.isUpcoming, isTrue);
  });
}
