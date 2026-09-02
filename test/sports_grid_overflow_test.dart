import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/bottombar/profile.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/services/selected_ground.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/repositories/coaching_repository.dart';

/// Layout regression tests for the sports grid on the Coaching tab.
///
/// The tile clips its children to get rounded corners, so an overflowing name
/// was painted as a cropped one rather than the usual overflow stripes — the
/// bug was invisible to the eye and to any test that only looked at pixels.
/// The RenderFlex still reports the overflow to `FlutterError`, though, which
/// is what `tester.takeException()` picks up here.
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

const String _venuesJson = '''
{"success": true, "data": {"sportsComplexes": [
  {"id": 1, "name": "Sinhagad Road"},
  {"id": 2, "name": "Gangadham Chowk"}
]}}
''';

/// The real catalogue's longest names, plus one well past anything the API
/// holds today — API text is not the client's to assume the length of.
String _sportsJson(List<String> names) => jsonEncode({
      'success': true,
      'data': [
        for (var i = 0; i < names.length; i++)
          {
            'id': 100 + i,
            'name': names[i],
            'category': 'Indoor',
            'status': 'Active',
          },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> sportNames;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    CoachingRepository.instance.invalidateCache();
    await SelectedGround.instance.clear();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    sportNames = const ['Multipurpose AC Studio'];

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sports-complexes')) {
        return http.Response(_venuesJson, 200);
      }
      return http.Response(_sportsJson(sportNames), 200);
    }));
  });

  tearDown(() {
    ApiClient.instance.overrideHttpClient(http.Client());
  });

  /// Pumps the coaching screen at a given viewport and system text scale.
  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Set on the dispatcher, not in a wrapping MediaQuery: MaterialApp builds
    // its own MediaQuery.fromView, which would discard an ancestor one and
    // quietly run every case at 1.0.
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(home: SportsScreen()));
    await tester.pumpAndSettle();
  }

  /// Asserts [text] is laid out in full — neither truncated by `maxLines` nor
  /// squeezed into a box shorter than the lines it needs.
  ///
  /// Checking only for a RenderFlex overflow is not enough here: `Flexible`
  /// suppresses the exception while still letting the text be shortened, which
  /// is precisely the "cropped name" that was reported. The height comparison
  /// is what actually pins the behaviour.
  void expectRendersInFull(WidgetTester tester, String text) {
    final paragraph = tester.renderObject<RenderParagraph>(find.text(text));

    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"$text" was truncated with an ellipsis',
    );

    final needed = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
    expect(
      paragraph.size.height,
      greaterThanOrEqualTo(needed - 0.5),
      reason: '"$text" is squeezed into ${paragraph.size.height}px '
          'but needs ${needed}px at ${paragraph.size.width}px wide',
    );
  }

  group('a long sport name renders in full', () {
    const name = 'Multipurpose AC Studio';

    testWidgets('on a small phone', (tester) async {
      await pump(tester, size: const Size(320, 568));

      expect(tester.takeException(), isNull);
      expectRendersInFull(tester, name);
    });

    testWidgets('on a normal phone', (tester) async {
      await pump(tester, size: const Size(390, 844));
      expect(tester.takeException(), isNull);
      expectRendersInFull(tester, name);
    });

    testWidgets('on a large phone', (tester) async {
      await pump(tester, size: const Size(430, 932));
      expect(tester.takeException(), isNull);
      expectRendersInFull(tester, name);
    });

    testWidgets('at 1.3x system text size', (tester) async {
      await pump(tester, size: const Size(360, 720), textScale: 1.3);
      expect(tester.takeException(), isNull);
      expectRendersInFull(tester, name);
    });

    testWidgets('at 2.0x system text size on a small phone', (tester) async {
      // The accessibility ceiling most users can actually reach. The tile is
      // expected to grow, not to clip.
      await pump(tester, size: const Size(320, 568), textScale: 2.0);
      expect(tester.takeException(), isNull);
      expectRendersInFull(tester, name);
    });
  });

  testWidgets('a name far longer than anything the API holds still fits',
      (tester) async {
    sportNames = const [
      'Multipurpose Air Conditioned Studio and Fitness Centre Annexe',
    ];

    await pump(tester, size: const Size(320, 568), textScale: 1.3);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole live catalogue lays out cleanly', (tester) async {
    sportNames = const [
      'Multipurpose AC Studio',
      'Gymnastics (Artistic)',
      'Fitness & Malkhamb',
      'Dance Classes',
      'Cricket Nets',
      'Pickleball',
      'Basketball',
      'Badminton',
      'Skating',
      'Zumba',
    ];

    await pump(tester, size: const Size(320, 568), textScale: 1.3);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty name does not collapse the tile', (tester) async {
    // API text can be blank; the tile must still be a tile.
    sportNames = const [''];

    await pump(tester, size: const Size(360, 720));

    expect(tester.takeException(), isNull);
  });
}
