import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Logging that is a no-op in release builds and never prints credentials.
///
/// All output is routed through `dart:developer` so it stays out of stdout in
/// profile/release modes, and every payload is passed through [redact] which
/// strips tokens, passwords and authorization headers.
class AppLogger {
  const AppLogger._();

  /// Master switch — logging is on in debug only, unless explicitly enabled
  /// with `--dart-define=ENABLE_API_LOGS=true`.
  static const bool _forceEnabled = bool.fromEnvironment(
    'ENABLE_API_LOGS',
    defaultValue: false,
  );

  static bool get enabled => kDebugMode || _forceEnabled;

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
    return headers.map((key, value) {
      if (_sensitiveHeaders.contains(key.toLowerCase())) {
        return MapEntry(key, '***');
      }
      return MapEntry(key, value);
    });
  }

  static void debug(String message, {String name = 'API'}) {
    if (!enabled) return;
    final text = redact(message);
    developer.log(text, name: name);
    // developer.log only reaches the IDE's log view; debugPrint puts the same
    // line in the plain `flutter run` console.
    debugPrint('[$name] $text');
  }

  /// Logs an outgoing call: method, URL and the full request body.
  static void request(
    String method,
    Object url, {
    Object? body,
    Map<String, String>? headers,
    String name = 'API',
  }) {
    if (!enabled) return;
    debug('➡️ $method $url', name: name);
    if (headers != null) {
      debug('   headers: ${redactHeaders(headers)}', name: name);
    }
    debug(
      '   request body: ${body == null ? '(none)' : truncate(redact(body))}',
      name: name,
    );
  }

  /// Logs the reply: status and the response body.
  static void response(
    Object url, {
    required int statusCode,
    required Object? body,
    Duration? elapsed,
    String name = 'API',
  }) {
    if (!enabled) return;
    // The round-trip time rides on the status line: a slow call is a defect
    // you can only see if it is measured.
    final took = elapsed == null ? '' : ' (${elapsed.inMilliseconds}ms)';
    debug('⬅️ $statusCode $url$took', name: name);
    debug('   response body: ${truncate(redact(body))}', name: name);
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

  /// Truncates long bodies so logs stay readable.
  static String truncate(Object? input, [int max = 4000]) {
    final value = input?.toString() ?? 'null';
    if (value.length <= max) return value;
    return '${value.substring(0, max)}… (${value.length} chars)';
  }
}
