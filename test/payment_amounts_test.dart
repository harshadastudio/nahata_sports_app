import 'package:flutter_test/flutter_test.dart';
import 'package:nahata_app/core/utils/payment_amounts.dart';

void main() {
  group('orderMatchesExpected', () {
    test('an order for exactly the discounted total is accepted', () {
      // ₹650 shown after a ₹150 coupon on ₹800.
      expect(orderMatchesExpected(65000, 650), isTrue);
    });

    test('a coupon applied twice is caught', () {
      // The screen showed ₹650; the backend took the 20% off again.
      expect(orderMatchesExpected(52000, 650), isFalse);
    });

    test('a coupon the backend ignored is caught', () {
      // The screen promised ₹650, the order is for the full ₹800.
      expect(orderMatchesExpected(80000, 650), isFalse);
    });

    test('rupee rounding either way is tolerated', () {
      expect(orderMatchesExpected(65000, 650.4), isTrue);
      expect(orderMatchesExpected(65100, 650), isTrue);
      expect(orderMatchesExpected(64900, 650), isTrue);
    });

    test('more than a rupee out is not rounding', () {
      expect(orderMatchesExpected(65200, 650), isFalse);
      expect(orderMatchesExpected(64800, 650), isFalse);
    });

    test('a string amount is read', () {
      expect(orderMatchesExpected('65000', 650), isTrue);
      expect(orderMatchesExpected('80000', 650), isFalse);
    });

    test('a backend that reports no amount is not second-guessed', () {
      // The check needs a number; refusing every checkout would be worse.
      expect(orderMatchesExpected(null, 650), isTrue);
      expect(orderMatchesExpected('', 650), isTrue);
      expect(orderMatchesExpected(0, 650), isTrue);
    });
  });
}
