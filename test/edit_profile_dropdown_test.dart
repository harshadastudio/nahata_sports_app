import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The dropdown options and the matcher, mirrored from `EditProfileScreen`.
///
/// The screen itself needs a signed-in session and three network calls to
/// build, so what is pinned here is the rule that broke: a value the API
/// returned must never reach `DropdownButtonFormField.value` unless the item
/// list contains it exactly.
const List<String> genderOptions = ['Male', 'Female', 'Other'];
const List<String> bloodGroupOptions = [
  'A+',
  'A-',
  'B+',
  'B-',
  'O+',
  'O-',
  'AB+',
  'AB-',
];

String? matchOption(String? value, List<String> options) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  for (final option in options) {
    if (option.toLowerCase() == text.toLowerCase()) return option;
  }
  return null;
}

void main() {
  group('matchOption', () {
    test('drops a value the dropdown has no item for', () {
      // The live bug: /auth/profile and /students/me both return "o" for a
      // blood group the form offers as "O+". Passing it straight through
      // asserted in DropdownButtonFormField and took the screen down.
      expect(matchOption('o', bloodGroupOptions), isNull);
      expect(matchOption('unknown', genderOptions), isNull);
    });

    test('matches regardless of case or padding', () {
      expect(matchOption('o+', bloodGroupOptions), 'O+');
      expect(matchOption(' MALE ', genderOptions), 'Male');
      expect(matchOption('AB-', bloodGroupOptions), 'AB-');
    });

    test('treats null, empty and the string "null" as unset', () {
      for (final value in [null, '', '   ', 'null']) {
        expect(matchOption(value, genderOptions), isNull, reason: '$value');
      }
    });

    test('never returns a value outside the option list', () {
      for (final value in ['o', 'O+', 'x', '', 'MALE', null]) {
        final matched = matchOption(value, bloodGroupOptions);
        if (matched != null) {
          expect(bloodGroupOptions, contains(matched));
        }
      }
    });
  });

  testWidgets('a dropdown fed a normalised value builds instead of asserting',
      (tester) async {
    Widget dropdown(String? apiValue) => MaterialApp(
          home: Scaffold(
            body: DropdownButtonFormField<String>(
              value: matchOption(apiValue, bloodGroupOptions),
              items: bloodGroupOptions
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (_) {},
            ),
          ),
        );

    // The value that crashed: renders empty rather than throwing.
    await tester.pumpWidget(dropdown('o'));
    expect(tester.takeException(), isNull);

    // A value the list does contain still selects.
    await tester.pumpWidget(dropdown('O+'));
    expect(tester.takeException(), isNull);
    expect(find.text('O+'), findsOneWidget);
  });
}