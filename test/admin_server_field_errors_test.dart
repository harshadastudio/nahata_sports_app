import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/presentation/utils/server_field_errors.dart';

/// The admin API reports database constraint failures in the message and never
/// in `errors`, so without parsing them a rejected value lands in the form
/// banner and nowhere near the box that caused it.
void main() {
  group('ServerFieldErrors.parseRejectedValue', () {
    // Captured live on 2026-08-04 from POST /admin/security-guards.
    const live =
        'invalid input value for enum "enum_SecurityGuards_assignedArea": '
        '"Backgate"';

    test('reads the column and the refused value out of the live message', () {
      final rejected = ServerFieldErrors.parseRejectedValue(live);

      expect(rejected, isNotNull);
      expect(rejected!.field, 'assignedArea');
      expect(rejected.value, 'Backgate');
      expect(rejected.fieldLabel, 'Assigned area');
      expect(rejected.message, contains('"Backgate"'));
      expect(rejected.message, contains('assigned area'));
    });

    test('accepts the unquoted form too', () {
      final rejected = ServerFieldErrors.parseRejectedValue(
        'invalid input value for enum enum_SecurityGuards_shift: Graveyard',
      );

      expect(rejected!.field, 'shift');
      expect(rejected.value, 'Graveyard');
    });

    test('a snake_case column survives the split', () {
      // The type name is enum_<Table>_<column>, so only the first two segments
      // are structural — the rest is the column, underscores and all.
      final rejected = ServerFieldErrors.parseRejectedValue(
        'invalid input value for enum "enum_SecurityGuards_assigned_area": "X"',
      );

      expect(rejected!.field, 'assigned_area');
      expect(rejected.fieldLabel, 'Assigned area');
    });

    test('an ordinary message is left alone', () {
      // Never mangle a normal failure into a field error it does not belong to.
      for (final message in const [
        'Security guard not found',
        'Validation failed',
        'invalid input value for enum "badname": "X"',
        '',
      ]) {
        expect(ServerFieldErrors.parseRejectedValue(message), isNull);
      }
    });
  });

  group('ServerFieldErrors.from', () {
    test('attaches the rejection to its own field and rewrites the summary',
        () {
      final parsed = ServerFieldErrors.from(
        const BadRequestException(
          'invalid input value for enum "enum_SecurityGuards_assignedArea": '
          '"Backgate"',
        ),
        fieldLabel: 'Assigned area',
      );

      expect(parsed.forKeys(const ['assignedArea', 'assigned_area']),
          contains('Backgate'));
      expect(parsed.rejected?.value, 'Backgate');
      // The banner gets the readable sentence rather than the raw SQL noise.
      expect(parsed.summary, isNot(contains('enum_SecurityGuards')));
      expect(parsed.isEmpty, isFalse);
    });

    test('a structured errors map still wins over the parsed message', () {
      // The server being explicit beats this class inferring from prose.
      final parsed = ServerFieldErrors.from(
        const BadRequestException(
          'invalid input value for enum "enum_SecurityGuards_assignedArea": '
          '"Backgate"',
          errors: {'assignedArea': 'Pick a gate on the north side'},
        ),
      );

      expect(parsed['assignedArea'], 'Pick a gate on the north side');
      expect(parsed.rejected?.value, 'Backgate');
    });

    test('an ordinary validation error passes through untouched', () {
      final parsed = ServerFieldErrors.from(
        const BadRequestException(
          'Validation failed',
          errors: {
            'email': ['Already in use'],
          },
        ),
      );

      expect(parsed['email'], 'Already in use');
      expect(parsed.rejected, isNull);
      expect(parsed.summary, isNull);
    });

    test('an error with nothing usable in it is empty', () {
      final parsed = ServerFieldErrors.from(
        const ServerException('Something went wrong'),
      );

      expect(parsed.isEmpty, isTrue);
      expect(parsed.forKeys(const ['anything']), isNull);
    });
  });
}
