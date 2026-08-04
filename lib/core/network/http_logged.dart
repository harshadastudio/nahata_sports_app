/// Drop-in replacement for `package:http` that logs every call.
///
/// Screens that still talk to the legacy backend directly only need to swap
/// their import:
///
/// ```dart
/// // import 'package:http/http.dart' as http;
/// import 'package:nahata_app/core/network/http_logged.dart' as http;
/// ```
///
/// Call sites stay exactly as they are — `http.get`, `http.post`, `http.Response`
/// and everything else keep working, but the request and response bodies now
/// reach the console. Traffic that goes through [ApiClient] is already logged.
library;

export 'package:http/http.dart'
    hide get, post, put, patch, delete, head, read, readBytes;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/app_logger.dart';

const String _name = 'HTTP';

Future<http.Response> get(Uri url, {Map<String, String>? headers}) => _send(
  'GET',
  url,
  headers: headers,
  call: () => http.get(url, headers: headers),
);

Future<http.Response> post(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _send(
  'POST',
  url,
  headers: headers,
  body: body,
  call: () => http.post(url, headers: headers, body: body, encoding: encoding),
);

Future<http.Response> put(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _send(
  'PUT',
  url,
  headers: headers,
  body: body,
  call: () => http.put(url, headers: headers, body: body, encoding: encoding),
);

Future<http.Response> patch(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _send(
  'PATCH',
  url,
  headers: headers,
  body: body,
  call: () => http.patch(url, headers: headers, body: body, encoding: encoding),
);

Future<http.Response> delete(
  Uri url, {
  Map<String, String>? headers,
  Object? body,
  Encoding? encoding,
}) => _send(
  'DELETE',
  url,
  headers: headers,
  body: body,
  call: () =>
      http.delete(url, headers: headers, body: body, encoding: encoding),
);

Future<http.Response> head(Uri url, {Map<String, String>? headers}) => _send(
  'HEAD',
  url,
  headers: headers,
  call: () => http.head(url, headers: headers),
);

Future<String> read(Uri url, {Map<String, String>? headers}) async =>
    (await get(url, headers: headers)).body;

Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async =>
    (await get(url, headers: headers)).bodyBytes;

/// Logs the call around [call], and never lets logging break the request.
Future<http.Response> _send(
  String method,
  Uri url, {
  required Future<http.Response> Function() call,
  Map<String, String>? headers,
  Object? body,
}) async {
  AppLogger.request(method, url, body: body, headers: headers, name: _name);

  try {
    final response = await call();
    AppLogger.response(
      url,
      statusCode: response.statusCode,
      body: response.body,
      name: _name,
    );
    return response;
  } catch (e) {
    AppLogger.error('$method $url failed', name: _name, error: e);
    rethrow;
  }
}
