import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/event_booking_model.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a free slot', () {
    test('is priced at zero, not treated as missing', () {
      // Event 7 slot 32 on the live API — "Children's Growth & Nutrition".
      final slot = EventPassSlot.fromJson({
        'id': 32,
        'name': 'Nahata Sports',
        'price': '0.00',
        'status': 'Active',
      });

      expect(slot.priceValue, 0);
      expect(slot.isActive, isTrue);
    });

    test('an event whose only slot is free has a lowest price of zero', () {
      final pass = EventPassModel.fromJson({
        'id': 7,
        'title': "Children's Growth & Nutrition",
        'status': 'Active',
        'slots': [
          {'id': 32, 'price': '0.00', 'status': 'Active'},
        ],
      });

      expect(pass.lowestPrice, 0);
    });
  });

  group('booking status decides whether a pass has a QR', () {
    EventPassBooking booking(String status) =>
        EventPassBooking.fromJson({'id': 6, 'status': status});

    test('a Pending booking is not yet paid', () {
      // Nothing will move a free booking out of Pending — there is no payment
      // step — so the server must confirm it at creation.
      expect(booking('Pending').isPaid, isFalse);
    });

    test('a Confirmed booking counts as paid', () {
      expect(booking('Confirmed').isPaid, isTrue);
    });
  });

  group('createBooking for a free event', () {
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

    test('still posts the booking, with a zero total', () async {
      serve({
        'success': true,
        'data': {'id': 6, 'status': 'Confirmed'},
      });

      final result = await EventBookingRepository.instance.createBooking(
        eventPassId: 7,
        slotId: 32,
        passes: 1,
        amount: 0,
      );

      // The booking API is called exactly as it is for a paid event — the
      // free case skips the gateway, not the booking.
      expect(result.isOk, isTrue);
      expect(result.bookingId, 6);
      expect(lastBody()['totalAmount'], 0);
      expect(lastBody()['eventPassId'], 7);
      expect(lastBody()['slotId'], 32);
    });

    test('a rejected free booking still surfaces the server message', () async {
      serve({'success': false, 'message': 'Event is full'}, status: 400);

      final result = await EventBookingRepository.instance.createBooking(
        eventPassId: 7,
        slotId: 32,
        passes: 1,
        amount: 0,
      );

      expect(result.isOk, isFalse);
      expect(result.message, 'Event is full');
    });
  });
}
