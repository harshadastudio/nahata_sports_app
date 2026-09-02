import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Decoded payloads, keyed by the URI they came from.
///
/// Two things depend on this. Decoding is not cheap — a coach photo stored
/// inline runs to two megabytes of base64 — and, more importantly, `MemoryImage`
/// identifies itself by the *identity* of its byte list. Handing `Image.memory`
/// a freshly allocated list on every build would miss Flutter's image cache
/// every time and re-decode the whole picture, which is what made an inline
/// photo flicker or appear not to load at all.
///
/// Bounded because the payloads are large; the app never shows more than a
/// handful of inline images at once.
final Map<String, Uint8List?> _decoded = <String, Uint8List?>{};

const int _maxCachedDataUris = 8;

/// The bytes carried by a `data:<mime>;base64,<payload>` URI, or null when
/// [source] is not one.
///
/// Returns null rather than throwing on a malformed payload so callers can
/// fall through to their placeholder instead of crashing a screen over a bad
/// image field. The same list instance comes back for the same [source], which
/// is what keeps the decode out of the build path.
Uint8List? decodeDataUri(String source) {
  if (!source.startsWith('data:')) return null;

  final cached = _decoded[source];
  if (cached != null || _decoded.containsKey(source)) return cached;

  Uint8List? result;
  final comma = source.indexOf(',');
  if (comma >= 0 && source.substring(0, comma).contains('base64')) {
    try {
      result = base64Decode(source.substring(comma + 1));
    } catch (_) {
      result = null;
    }
  }

  if (_decoded.length >= _maxCachedDataUris) {
    _decoded.remove(_decoded.keys.first);
  }
  _decoded[source] = result;
  return result;
}

/// An image from the API, in whichever form the field arrived.
///
/// Most routes send a URL. Some coach records instead carry the picture inline
/// as a `data:` URI — `Image.network` cannot load one of those at all, so the
/// bytes have to be decoded and handed to `Image.memory`. This picks the right
/// one so callers do not have to know which they were given.
///
/// A format Flutter cannot decode (AVIF, notably — some coach photos are
/// stored that way) fails through [errorBuilder] like any other bad image.
class MediaImage extends StatelessWidget {
  const MediaImage({
    super.key,
    required this.source,
    required this.errorBuilder,
    this.width,
    this.height,
    this.fit,
    this.decodeSize,
  });

  final String source;
  final ImageErrorWidgetBuilder errorBuilder;
  final double? width;
  final double? height;
  final BoxFit? fit;

  /// Longest edge, in pixels, to decode the image at. A coach photo arrives at
  /// well over a thousand pixels square and is shown in a 120px avatar — held
  /// at full resolution that is megabytes of memory for nothing. Null decodes
  /// at the source's own size.
  final int? decodeSize;

  @override
  Widget build(BuildContext context) {
    final bytes = decodeDataUri(source);

    if (bytes != null) {
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: decodeSize,
        errorBuilder: errorBuilder,
      );
    }

    return Image.network(
      source,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: decodeSize,
      errorBuilder: errorBuilder,
    );
  }
}
