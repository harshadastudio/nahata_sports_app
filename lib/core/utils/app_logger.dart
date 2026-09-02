import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Console logging for every API call the app makes.
///
/// Prints the method, the full URL (query string included), the headers, the
/// complete request body and the complete response body with its status code
/// and round-trip time. Bodies are pretty-printed when they are JSON and are
/// emitted in chunks, so a large payload reaches the console whole instead of
/// being clipped by `debugPrint`'s line wrapping or by logcat.
///
/// Two switches, both `--dart-define`:
///
/// * `ENABLE_API_LOGS=true` — also log in profile/release builds. Debug builds
///   log unconditionally.
/// * `LOG_RAW_BODIES=true` — print tokens, passwords and `Authorization`
///   headers verbatim. Off by default: [redact] masks them, which is what you
///   want unless you are specifically debugging auth.
class AppLogger {
  const AppLogger._();

  /// Master switch — logging is on in debug only, unless explicitly enabled
  /// with `--dart-define=ENABLE_API_LOGS=true`.
  static const bool _forceEnabled = bool.fromEnvironment(
    'ENABLE_API_LOGS',
    defaultValue: false,
  );

  /// Opt out of masking with `--dart-define=LOG_RAW_BODIES=true`.
  static const bool _rawBodies = bool.fromEnvironment(
    'LOG_RAW_BODIES',
    defaultValue: false,
  );

  static bool get enabled => kDebugMode || _forceEnabled;

  /// Longest single line handed to `debugPrint`. Flutter word-wraps at 1024 and
  /// logcat drops what overflows its own buffer, so bodies are split below both.
  static const int _chunkSize = 800;

  static final List<RegExp> _sensitivePatterns = <RegExp>[
    RegExp(
      r'("(?:access|refresh)?[_-]?token"\s*:\s*")[^"]*(")',
      caseSensitive: false,
    ),
    // Affixes matter: the admin console reads `temporaryPassword` and writes
    // `newPassword`, neither of which an exact-key pattern would catch — and
    // an unredacted staff password in the console is a real leak.
    RegExp(
      r'("[A-Za-z0-9_]*(?:password|passcode|secret|otp)[A-Za-z0-9_]*"\s*:\s*")[^"]*(")',
      caseSensitive: false,
    ),
    RegExp(r'(Bearer\s+)[A-Za-z0-9\-\._~\+\/]+=*', caseSensitive: false),
    RegExp(r'(eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.)[A-Za-z0-9_\-]+'),
  ];

  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-refresh-token',
  };

  /// Replaces token/password material in [input] with `***`.
  static String redact(Object? input) {
    if (input == null) return 'null';
    var text = input.toString();
    if (_rawBodies) return text;
    for (final pattern in _sensitivePatterns) {
      text = text.replaceAllMapped(pattern, (m) {
        final head = m.groupCount >= 1 ? (m.group(1) ?? '') : '';
        final tail = m.groupCount >= 2 ? (m.group(2) ?? '') : '';
        return '$head***$tail';
      });
    }
    return text;
  }

  /// Returns a copy of [headers] with sensitive values masked.
  static Map<String, String> redactHeaders(Map<String, String> headers) {
    if (_rawBodies) return Map<String, String>.of(headers);
    return headers.map((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  static void debug(String message, {String name = 'API'}) {
    if (!enabled) return;
    _emit(redact(message), name);
  }

  /// Logs an outgoing call as one labelled block.
  ///
  /// ```
  /// ========== API REQUEST ==========
  /// METHOD: POST
  /// URL: https://api.nahatasports.com/api/auth/login
  /// HEADERS: {Accept: application/json, Authorization: ***}
  /// QUERY PARAMETERS: (none)
  /// REQUEST BODY:
  /// { "email": "a@b.com", "password": "***" }
  /// =================================
  /// ```
  static void request(
    String method,
    Object url, {
    Object? body,
    Map<String, String>? headers,
    Map<String, dynamic>? query,
    String name = 'API',
  }) {
    if (!enabled) return;

    _emit('========== API REQUEST ==========', name);
    _emit('METHOD: $method', name);
    _emit('URL: $url', name);
    _emit(
      'HEADERS: ${headers == null || headers.isEmpty ? '(none)' : redactHeaders(headers)}',
      name,
    );

    // Taken off the Uri when the caller did not pass them separately, so a
    // query is shown for every call rather than only the ones that build it
    // as a map.
    final params = query ?? (url is Uri ? url.queryParameters : null);
    if (params == null || params.isEmpty) {
      _emit('QUERY PARAMETERS: (none)', name);
    } else {
      _emit('QUERY PARAMETERS:', name);
      params.forEach((key, value) => _emit('  $key: ${redact(value)}', name));
    }

    _emit('REQUEST BODY:', name);
    _emitBody(body, name);
    _emit('=================================', name);
  }

  /// Logs the reply as one labelled block.
  static void response(
    Object url, {
    required int statusCode,
    required Object? body,
    Duration? elapsed,
    Map<String, String>? headers,
    String name = 'API',
  }) {
    if (!enabled) return;

    _emit('========== API RESPONSE ==========', name);
    _emit('STATUS CODE: $statusCode', name);
    _emit('URL: $url', name);
    // The round-trip time rides along: a slow call is a defect you can only
    // see if it is measured.
    if (elapsed != null) _emit('TOOK: ${elapsed.inMilliseconds}ms', name);
    _emit(
      'RESPONSE HEADERS: ${headers == null || headers.isEmpty ? '(none)' : redactHeaders(headers)}',
      name,
    );
    _emit('RESPONSE BODY:', name);
    _emitBody(body, name);
    _emit('==================================', name);
  }

  /// Logs a failed call as one labelled block.
  ///
  /// Separate from [error] because a failed *request* has more to say than a
  /// message: what was sent, what came back, and where it threw. A blank
  /// screen is a bug you cannot diagnose without all three.
  static void apiError(
    String method,
    Object url, {
    int? statusCode,
    Object? requestBody,
    Object? responseBody,
    Object? error,
    StackTrace? stackTrace,
    String name = 'API',
  }) {
    if (!enabled) return;

    _emit('========== API ERROR ==========', name);
    _emit('METHOD: $method', name);
    _emit('URL: $url', name);
    _emit('STATUS CODE: ${statusCode ?? '(no response)'}', name);
    _emit('REQUEST BODY:', name);
    _emitBody(requestBody, name);
    _emit('ERROR: ${error == null ? '(none)' : redact(error)}', name);
    _emit('RESPONSE BODY:', name);
    _emitBody(responseBody, name);
    _emit('STACK TRACE:', name);
    if (stackTrace == null) {
      _emit('  (none)', name);
    } else {
      // Capped: the frames that matter are at the top, and an uncapped trace
      // buries the block that precedes it.
      for (final line in stackTrace.toString().split('\n').take(15)) {
        if (line.trim().isNotEmpty) _emit('  $line', name);
      }
    }
    _emit('===============================', name);

    // Also through dart:developer, so the IDE shows it as an error with the
    // trace attached rather than as plain lines.
    developer.log(
      '$method $url failed',
      name: name,
      error: error == null ? null : redact(error),
      stackTrace: stackTrace,
    );
  }

  static void info(String message, {String name = 'API'}) =>
      debug(message, name: name);

  static void error(
    String message, {
    String name = 'API',
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    final text = redact(message);
    developer.log(
      text,
      name: name,
      error: error == null ? null : redact(error),
      stackTrace: stackTrace,
    );
    debugPrint('[$name] ❌ $text${error == null ? '' : ' :: ${redact(error)}'}');
  }

  /// Truncates long bodies. Kept for callers that want a one-line summary;
  /// request/response bodies are no longer passed through it.
  static String truncate(Object? input, [int max = 4000]) {
    final value = input?.toString() ?? 'null';
    if (value.length <= max) return value;
    return '${value.substring(0, max)}… (${value.length} chars)';
  }

  /// Pretty-prints [body] when it is JSON, then emits it whole.
  static void _emitBody(Object? body, String name) {
    if (body == null) {
      _emit('     (none)', name);
      return;
    }

    final text = redact(_pretty(body));
    if (text.isEmpty) {
      _emit('     (empty)', name);
      return;
    }

    for (final line in text.split('\n')) {
      if (line.length <= _chunkSize) {
        _emit(line, name);
        continue;
      }
      for (var i = 0; i < line.length; i += _chunkSize) {
        final end = (i + _chunkSize).clamp(0, line.length);
        _emit(line.substring(i, end), name);
      }
    }
  }

  /// JSON in, indented JSON out; anything else comes back as-is.
  static String _pretty(Object? body) {
    const encoder = JsonEncoder.withIndent('  ');

    if (body is Map || body is List) {
      try {
        return encoder.convert(body);
      } catch (_) {
        // Not JSON-encodable (an UploadFile, a stream) — its toString will do.
        return body.toString();
      }
    }

    final text = body.toString();
    final trimmed = text.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return encoder.convert(jsonDecode(trimmed));
      } catch (_) {
        // A body that only looks like JSON still has to be printed verbatim.
      }
    }
    return text;
  }

  static void _emit(String line, String name) {
    developer.log(line, name: name);
    // developer.log only reaches the IDE's log view; debugPrint puts the same
    // line in the plain `flutter run` console.
    debugPrint('[$name] $line');
  }
}
