import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nahata_app/core/widgets/media_image.dart';
import 'package:nahata_app/repositories/coaching_repository.dart';

/// The smallest valid PNG, as the API would send it inline.
const String _pngDataUri =
    'data:image/png;base64,'
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  group('resolveMediaUrl', () {
    test('an absolute URL is left alone', () {
      expect(
        resolveMediaUrl('https://api.nahatasports.com/uploads/a.png'),
        'https://api.nahatasports.com/uploads/a.png',
      );
    });

    test('a bare filename is resolved against the media host', () {
      expect(resolveMediaUrl('coach.png'), endsWith('/coach.png'));
    });

    test('a data URI is passed through, not prefixed with the media host', () {
      // Prefixing turned the picture into
      // `https://…/public/uploads/data:image/png;base64,…`, which is why the
      // two coaches whose photo is stored inline showed a placeholder.
      expect(resolveMediaUrl(_pngDataUri), _pngDataUri);
    });

    test('nothing in, nothing out', () {
      expect(resolveMediaUrl(null), isNull);
      expect(resolveMediaUrl('   '), isNull);
    });
  });

  group('decodeDataUri', () {
    test('reads the bytes out of a base64 data URI', () {
      final bytes = decodeDataUri(_pngDataUri);
      expect(bytes, isNotNull);
      // PNG magic number.
      expect(bytes!.take(4), [0x89, 0x50, 0x4E, 0x47]);
    });

    test('a plain URL is not a data URI', () {
      expect(decodeDataUri('https://example.com/a.png'), isNull);
    });

    test('a malformed payload yields null rather than throwing', () {
      expect(decodeDataUri('data:image/png;base64,%%%not-base64%%%'), isNull);
      expect(decodeDataUri('data:image/png'), isNull);
    });

    test('the same source decodes once and returns the same bytes', () {
      // MemoryImage identifies itself by the identity of its byte list, so a
      // fresh list per build would miss Flutter's image cache and re-decode
      // the whole picture every time — two megabytes, on a coach avatar.
      final first = decodeDataUri(_pngDataUri);
      final second = decodeDataUri(_pngDataUri);

      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
    });

    test('a malformed payload is not retried on every call', () {
      const bad = 'data:image/png;base64,%%%still-not-base64%%%';
      expect(decodeDataUri(bad), isNull);
      expect(decodeDataUri(bad), isNull);
    });
  });

  group('MediaImage', () {
    Widget host(String source) => MaterialApp(
          home: Scaffold(
            body: MediaImage(
              source: source,
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => const Text('placeholder'),
            ),
          ),
        );

    testWidgets('an inline photo is decoded rather than fetched',
        (tester) async {
      await tester.pumpWidget(host(_pngDataUri));
      await tester.pump();

      // Image.network would have failed on a data: URI; Image.memory does not.
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('placeholder'), findsNothing);
    });

    testWidgets('an undecodable inline photo falls back to the placeholder',
        (tester) async {
      // AVIF is what one coach record actually holds, and Flutter cannot
      // decode it — the screen must degrade, not throw.
      final avif = 'data:image/avif;base64,${base64Encode(
        List<int>.filled(32, 0),
      )}';

      await tester.pumpWidget(host(avif));
      await tester.pumpAndSettle();

      expect(find.text('placeholder'), findsOneWidget);
    });
  });
}
