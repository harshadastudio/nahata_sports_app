import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../api/api_trace.dart';
import '../config/api_config.dart';
import '../storage/token_storage.dart';
import '../utils/app_logger.dart';
import 'api_exception.dart';
import 'api_response.dart';

/// A file to be attached to a multipart request.
///
/// The path (rather than an open stream) is kept so the request can be rebuilt
/// byte-for-byte if it has to be retried after a token refresh.
class UploadFile {
  const UploadFile({
    required this.field,
    required this.path,
    this.filename,
    this.contentType,
  });

  final String field;
  final String path;
  final String? filename;
  final String? contentType;
}

enum _RefreshOutcome {
  /// New tokens obtained; the caller may retry.
  refreshed,

  /// The refresh token itself was rejected — the session is over.
  rejected,

  /// Network/timeout during refresh; the session may still be valid.
  transient,
}

/// Callback invoked exactly once when the session can no longer be recovered.
typedef SessionExpiredCallback = Future<void> Function();

/// Centralised HTTP client for the whole app.
///
/// Responsibilities (the equivalent of a Dio interceptor chain, built on the
/// `http` package this project already uses):
///
/// * injects `Authorization: Bearer <accessToken>` on authenticated calls,
/// * refreshes proactively when the access token's `exp` has passed,
/// * on a `401`, refreshes once via `/auth/refresh` and replays the original
///   request — preserving method, query, headers, body and multipart files,
/// * collapses concurrent refreshes into a single in-flight call,
/// * never retries more than once, so no refresh/retry loop is possible,
/// * maps every transport/HTTP failure onto a typed [ApiException].
class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();

  http.Client _client = http.Client();

  final TokenStorage _tokens = TokenStorage.instance;

  /// Set by `SessionManager`; called when refresh definitively fails.
  SessionExpiredCallback? onSessionExpired;

  Completer<_RefreshOutcome>? _refreshCompleter;

  /// Replaces the underlying client. Test seam only.
  void overrideHttpClient(http.Client client) => _client = client;

  // ---------------------------------------------------------------------------
  // Public verbs
  // ---------------------------------------------------------------------------

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
  }) {
    return _send(
      method: 'GET',
      path: path,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      baseUrl: baseUrl,
      timeout: timeout,
    );
  }

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
  }) {
    return _send(
      method: 'POST',
      path: path,
      body: body,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      baseUrl: baseUrl,
      timeout: timeout,
    );
  }

  Future<ApiResponse> put(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
  }) {
    return _send(
      method: 'PUT',
      path: path,
      body: body,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      baseUrl: baseUrl,
      timeout: timeout,
    );
  }

  Future<ApiResponse> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
  }) {
    return _send(
      method: 'PATCH',
      path: path,
      body: body,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      baseUrl: baseUrl,
      timeout: timeout,
    );
  }

  Future<ApiResponse> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
  }) {
    return _send(
      method: 'DELETE',
      path: path,
      body: body,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      baseUrl: baseUrl,
      timeout: timeout,
    );
  }

  /// Multipart upload with the same auth/refresh/retry semantics as the
  /// JSON verbs. Files are re-read from disk on retry.
  Future<ApiResponse> multipart(
    String path, {
    String method = 'POST',
    Map<String, String> fields = const {},
    List<UploadFile> files = const [],
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
  }) {
    return _send(
      method: method,
      path: path,
      query: query,
      headers: headers,
      requiresAuth: requiresAuth,
      baseUrl: baseUrl,
      timeout: timeout ?? ApiConfig.uploadTimeout,
      fields: fields,
      files: files,
    );
  }

  // ---------------------------------------------------------------------------
  // Core pipeline
  // ---------------------------------------------------------------------------

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Map<String, dynamic>? query,
    Object? body,
    Map<String, String>? headers,
    bool requiresAuth = true,
    String? baseUrl,
    Duration? timeout,
    Map<String, String>? fields,
    List<UploadFile>? files,
    bool allowRefresh = true,
  }) async {
    final uri = _buildUri(baseUrl ?? ApiConfig.baseUrl, path, query);
    ApiConfig.assertSecure(uri.toString());

    final effectiveTimeout =
        timeout ??
        (method == 'GET' ? ApiConfig.receiveTimeout : ApiConfig.connectTimeout);

    // Proactive refresh: if we can see the access token is past `exp`, renew it
    // before spending a round trip on a guaranteed 401.
    if (requiresAuth && allowRefresh) {
      final access = await _tokens.accessToken;
      final refresh = await _tokens.refreshToken;
      if (_tokens.isExpired(access) && refresh != null && refresh.isNotEmpty) {
        await _refreshSession();
      }
    }

    // At most two passes: the original request, then one replay after refresh.
    for (var attempt = 0; attempt < 2; attempt++) {
      final response = await _execute(
        method: method,
        uri: uri,
        body: body,
        headers: headers,
        requiresAuth: requiresAuth,
        timeout: effectiveTimeout,
        fields: fields,
        files: files,
      );

      // Only a request made *with* a session can be recovered by refreshing.
      // A guest browsing public screens must never be bounced to Login.
      final hasSession = await _tokens.hasSession;

      final needsRefresh =
          response.statusCode == 401 &&
          requiresAuth &&
          allowRefresh &&
          hasSession &&
          attempt == 0;

      if (needsRefresh) {
        final outcome = await _refreshSession();
        if (outcome == _RefreshOutcome.refreshed) {
          continue; // Replay once with the new access token.
        }
        if (outcome == _RefreshOutcome.transient) {
          throw const NoInternetException();
        }
        throw const UnauthorizedException(
          AuthMessages.sessionExpired,
          sessionExpired: true,
        );
      }

      if (!response.isSuccess) {
        if (response.statusCode == 401) {
          // Second 401, or nothing to refresh with — stop here, never loop.
          throw UnauthorizedException(
            hasSession
                ? AuthMessages.sessionExpired
                : (response.message ?? 'Please login to continue.'),
            sessionExpired: hasSession,
          );
        }
        throw response.toException();
      }

      return response;
    }

    throw const UnknownApiException();
  }

  Future<ApiResponse> _execute({
    required String method,
    required Uri uri,
    required bool requiresAuth,
    required Duration timeout,
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<UploadFile>? files,
  }) async {
    final isMultipart = files != null || fields != null;
    final requestHeaders = await _buildHeaders(
      requiresAuth: requiresAuth,
      extra: headers,
      isMultipart: isMultipart,
    );

    // Who is calling, and which module — printed for every request, so a
    // role-mapped console can be read off the log rather than guessed at.
    // Nothing here can carry a credential: it prints the role, the module and
    // the venue id only.
    ApiTrace.context(uri.path);

    // Kept so the failure block can show what was sent, not just what came
    // back — a 400 is unreadable without the body that caused it.
    final Object? loggedBody = isMultipart
        ? {
            'fields': fields ?? const <String, String>{},
            'files': [
              for (final file in files ?? const <UploadFile>[])
                {
                  'field': file.field,
                  'filename':
                      file.filename ??
                      file.path.split(Platform.pathSeparator).last,
                  'path': file.path,
                  if (file.contentType != null) 'contentType': file.contentType,
                },
            ],
          }
        : body;

    AppLogger.request(
      method,
      uri,
      // A multipart body has no single payload to print, so it is described:
      // every text field verbatim, and every attachment by field, filename and
      // type — enough to tell a missing field from a missing file.
      body: loggedBody,
      headers: requestHeaders,
      // The query is already folded into `uri` by this point; AppLogger reads
      // it back off there.
    );

    final stopwatch = Stopwatch()..start();

    try {
      final http.Response response;

      if (isMultipart) {
        response = await _sendMultipart(
          method: method,
          uri: uri,
          headers: requestHeaders,
          fields: fields ?? const {},
          files: files ?? const [],
          timeout: timeout,
        );
      } else {
        response = await _sendSimple(
          method: method,
          uri: uri,
          headers: requestHeaders,
          body: body,
          timeout: timeout,
        );
      }

      AppLogger.response(
        uri,
        statusCode: response.statusCode,
        body: response.body,
        elapsed: stopwatch.elapsed,
        headers: response.headers,
      );

      // A non-2xx still reaches the caller as a typed exception, but the
      // console gets the full failure block first — that is the only place
      // the request body and the server's own words sit side by side.
      if (response.statusCode >= 400) {
        AppLogger.apiError(
          method,
          uri,
          statusCode: response.statusCode,
          requestBody: loggedBody,
          responseBody: response.body,
          error: 'HTTP ${response.statusCode}',
        );
      }

      return ApiResponse.parse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on SocketException catch (e, s) {
      _logFailure(method, uri, loggedBody, e, s, stopwatch);
      throw NoInternetException(cause: e);
    } on HttpException catch (e, s) {
      _logFailure(method, uri, loggedBody, e, s, stopwatch);
      throw UnknownApiException(message: AuthMessages.unknown, cause: e);
    } on TimeoutException catch (e, s) {
      _logFailure(method, uri, loggedBody, e, s, stopwatch);
      throw RequestTimeoutException(cause: e);
    } on FormatException catch (e, s) {
      _logFailure(method, uri, loggedBody, e, s, stopwatch);
      throw ParseException(
        'Received an unexpected response from the server.',
        cause: e,
      );
    } on ApiException {
      // Already logged where it was raised; re-logging would double the block.
      rethrow;
    } catch (e, s) {
      // Anything else (a plugin error, a platform exception, an unexpected
      // transport failure) still reaches the caller as a typed ApiException,
      // so no screen ever sees a raw exception it cannot present.
      _logFailure(method, uri, loggedBody, e, s, stopwatch);
      throw UnknownApiException(cause: e);
    }
  }

  /// One API ERROR block for a call that never produced a response.
  static void _logFailure(
    String method,
    Uri uri,
    Object? requestBody,
    Object error,
    StackTrace stackTrace,
    Stopwatch stopwatch,
  ) {
    AppLogger.apiError(
      method,
      uri,
      requestBody: requestBody,
      responseBody: '(no response after ${stopwatch.elapsedMilliseconds}ms)',
      error: error,
      stackTrace: stackTrace,
    );
  }

  Future<http.Response> _sendSimple({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Duration timeout,
    Object? body,
  }) {
    final encoded = body == null
        ? null
        : (body is String ? body : jsonEncode(body));

    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        return _client
            .post(uri, headers: headers, body: encoded)
            .timeout(timeout);
      case 'PUT':
        return _client
            .put(uri, headers: headers, body: encoded)
            .timeout(timeout);
      case 'PATCH':
        return _client
            .patch(uri, headers: headers, body: encoded)
            .timeout(timeout);
      case 'DELETE':
        return _client
            .delete(uri, headers: headers, body: encoded)
            .timeout(timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  Future<http.Response> _sendMultipart({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, String> fields,
    required List<UploadFile> files,
    required Duration timeout,
  }) async {
    final request = http.MultipartRequest(method, uri)
      ..headers.addAll(headers)
      ..fields.addAll(fields);

    for (final file in files) {
      final contentType = await _contentTypeFor(file);

      request.files.add(
        await http.MultipartFile.fromPath(
          file.field,
          file.path,
          filename: _filenameFor(file, contentType),
          contentType: contentType,
        ),
      );
    }

    final streamed = await _client.send(request).timeout(timeout);
    return http.Response.fromStream(streamed);
  }

  /// Content type for one multipart attachment.
  ///
  /// `MultipartFile.fromPath` sends `application/octet-stream` when it is not
  /// told otherwise, and an upload route that filters on `file.mimetype` — as
  /// `/auth/profile/picture` does — rejects that however valid the image is.
  ///
  /// The bytes decide. The extension is only a fallback, because a photo the
  /// picker re-encodes does not always get renamed to match, so the name on
  /// disk is the least reliable thing about it.
  static Future<MediaType?> _contentTypeFor(UploadFile file) async {
    final declared = file.contentType?.trim();
    if (declared != null && declared.isNotEmpty) {
      try {
        return MediaType.parse(declared);
      } on FormatException {
        // A malformed override is worth ignoring, not worth failing on.
      }
    }

    return await _sniff(file.path) ?? _fromExtension(file.path);
  }

  /// The first bytes of [path], matched against the magic numbers of the types
  /// these upload routes accept.
  static Future<MediaType?> _sniff(String path) async {
    List<int> head;
    try {
      final handle = await File(path).open();
      try {
        head = await handle.read(16);
      } finally {
        await handle.close();
      }
    } catch (_) {
      // Unreadable here means unreadable to `fromPath` too, which reports it
      // far better than a null content type would.
      return null;
    }

    bool matches(List<int> signature, [int offset = 0]) {
      if (head.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (head[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (matches([0xFF, 0xD8, 0xFF])) return MediaType('image', 'jpeg');
    if (matches([0x89, 0x50, 0x4E, 0x47])) return MediaType('image', 'png');
    if (matches([0x47, 0x49, 0x46, 0x38])) return MediaType('image', 'gif');
    if (matches([0x25, 0x50, 0x44, 0x46]))
      return MediaType('application', 'pdf');

    // RIFF....WEBP
    if (matches([0x52, 0x49, 0x46, 0x46]) &&
        matches([0x57, 0x45, 0x42, 0x50], 8)) {
      return MediaType('image', 'webp');
    }

    // ISO-BMFF: "ftyp" at offset 4, brand at 8. iOS hands these over whenever
    // the picker is not asked to re-encode.
    if (matches([0x66, 0x74, 0x79, 0x70], 4) && head.length >= 12) {
      final brand = String.fromCharCodes(head.sublist(8, 12));
      if (brand.startsWith('hei') || brand.startsWith('hev')) {
        return MediaType('image', 'heic');
      }
      if (brand.startsWith('mif') || brand.startsWith('msf')) {
        return MediaType('image', 'heif');
      }
    }

    return null;
  }

  /// Extension → mime type. `MediaType` has no const constructor, so the table
  /// holds the strings and the two readers parse what they need.
  static const Map<String, String> _typesByExtension = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'svg': 'image/svg+xml',
    'pdf': 'application/pdf',
  };

  static String? _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return name.substring(dot + 1).toLowerCase();
  }

  static MediaType? _fromExtension(String path) {
    final mime = _typesByExtension[_extensionOf(path) ?? ''];
    return mime == null ? null : MediaType.parse(mime);
  }

  /// The filename to send, with its extension corrected to match [contentType].
  ///
  /// Routes commonly check the extension of `originalname` as well as the
  /// mimetype, and the picker can hand back JPEG bytes under a `.png` name —
  /// which passes the mimetype check and fails the extension one. Renaming is
  /// safe: the extension only ever describes the bytes we are about to send.
  static String? _filenameFor(UploadFile file, MediaType? contentType) {
    final name = file.filename ?? file.path.split(Platform.pathSeparator).last;
    if (contentType == null) return file.filename;

    final mime = contentType.mimeType;

    String? wanted;
    for (final entry in _typesByExtension.entries) {
      if (entry.value == mime) {
        wanted = entry.key;
        break;
      }
    }
    if (wanted == null) return file.filename;

    // 'jpg' and 'jpeg' are the same type; leave a name that is already right.
    if (_typesByExtension[_extensionOf(name) ?? ''] == mime) {
      return file.filename;
    }

    final dot = name.lastIndexOf('.');
    final stem = dot < 0 ? name : name.substring(0, dot);
    return '$stem.$wanted';
  }

  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
    required bool isMultipart,
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};

    // MultipartRequest sets its own Content-Type (with the boundary).
    if (!isMultipart) headers['Content-Type'] = 'application/json';

    if (requiresAuth) {
      final token = await _tokens.accessToken;
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Uri _buildUri(String baseUrl, String path, Map<String, dynamic>? query) {
    final normalisedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalisedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalisedBase$normalisedPath');

    if (query == null || query.isEmpty) return uri;

    final params = <String, dynamic>{...uri.queryParameters};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        params[key] = value.map((e) => e.toString()).toList();
      } else {
        params[key] = value.toString();
      }
    });

    return uri.replace(queryParameters: params);
  }

  // ---------------------------------------------------------------------------
  // Refresh
  // ---------------------------------------------------------------------------

  /// Refreshes the session, collapsing concurrent callers onto one HTTP call.
  Future<_RefreshOutcome> _refreshSession() {
    final inFlight = _refreshCompleter;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<_RefreshOutcome>();
    _refreshCompleter = completer;

    _performRefresh()
        .then((outcome) {
          _refreshCompleter = null;
          completer.complete(outcome);
        })
        .catchError((Object error, StackTrace stack) {
          _refreshCompleter = null;
          AppLogger.error(
            'Refresh threw',
            name: 'Auth',
            error: error,
            stackTrace: stack,
          );
          completer.complete(_RefreshOutcome.rejected);
        });

    return completer.future;
  }

  Future<_RefreshOutcome> _performRefresh() async {
    final refreshToken = await _tokens.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      AppLogger.debug('No refresh token stored — session over', name: 'Auth');
      await _handleSessionExpired();
      return _RefreshOutcome.rejected;
    }

    final uri = _buildUri(ApiConfig.baseUrl, ApiEndpoints.refresh, null);
    AppLogger.debug('🔄 Refreshing session', name: 'Auth');

    try {
      // Sent directly through the raw client: the refresh call must never
      // re-enter the interceptor, otherwise a failure could recurse.
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $refreshToken',
            },
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(ApiConfig.connectTimeout);

      final parsed = ApiResponse.parse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );

      if (parsed.isSuccess && parsed.isOk) {
        final payload = parsed.payload;
        final newAccess = _stringOrNull(
          payload['accessToken'] ?? payload['access_token'] ?? payload['token'],
        );
        final newRefresh = _stringOrNull(
          payload['refreshToken'] ?? payload['refresh_token'],
        );

        if (newAccess != null) {
          await _tokens.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
          AppLogger.debug('✅ Session refreshed', name: 'Auth');
          return _RefreshOutcome.refreshed;
        }
      }

      // 5xx while refreshing is a server problem, not a rejected session —
      // keep the tokens so the next attempt can succeed.
      if (parsed.statusCode >= 500) {
        AppLogger.error(
          'Refresh failed with ${parsed.statusCode}',
          name: 'Auth',
        );
        return _RefreshOutcome.transient;
      }

      AppLogger.error('Refresh rejected (${parsed.statusCode})', name: 'Auth');
      await _handleSessionExpired();
      return _RefreshOutcome.rejected;
    } on SocketException catch (e) {
      AppLogger.error('Refresh offline', name: 'Auth', error: e);
      return _RefreshOutcome.transient;
    } on TimeoutException catch (e) {
      AppLogger.error('Refresh timed out', name: 'Auth', error: e);
      return _RefreshOutcome.transient;
    } catch (e, s) {
      AppLogger.error('Refresh error', name: 'Auth', error: e, stackTrace: s);
      await _handleSessionExpired();
      return _RefreshOutcome.rejected;
    }
  }

  Future<void> _handleSessionExpired() async {
    await _tokens.clear();
    final callback = onSessionExpired;
    if (callback != null) {
      await callback();
    }
  }

  static String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
