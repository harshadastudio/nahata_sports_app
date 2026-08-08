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

    AppLogger.request(
      method,
      uri,
      body: isMultipart ? {'fields': fields, 'files': files?.length} : body,
      headers: requestHeaders,
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
      );

      return ApiResponse.parse(
        statusCode: response.statusCode,
        body: response.body,
        headers: response.headers,
      );
    } on SocketException catch (e) {
      AppLogger.error(
        'Network unreachable for $uri after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
      );
      throw NoInternetException(cause: e);
    } on HttpException catch (e) {
      AppLogger.error('HTTP error for $uri', error: e);
      throw UnknownApiException(message: AuthMessages.unknown, cause: e);
    } on TimeoutException catch (e) {
      AppLogger.error(
        'Timeout for $uri after ${stopwatch.elapsedMilliseconds}ms',
        error: e,
      );
      throw RequestTimeoutException(cause: e);
    } on FormatException catch (e) {
      AppLogger.error('Malformed response from $uri', error: e);
      throw ParseException(
        'Received an unexpected response from the server.',
        cause: e,
      );
    } on ApiException {
      rethrow;
    } catch (e, s) {
      // Anything else (a plugin error, a platform exception, an unexpected
      // transport failure) still reaches the caller as a typed ApiException,
      // so no screen ever sees a raw exception it cannot present.
      AppLogger.error('Unexpected error for $uri', error: e, stackTrace: s);
      throw UnknownApiException(cause: e);
    }
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
      request.files.add(
        await http.MultipartFile.fromPath(
          file.field,
          file.path,
          filename: file.filename,
          contentType: file.contentType == null
              ? null
              : MediaType.parse(file.contentType!),
        ),
      );
    }

    final streamed = await _client.send(request).timeout(timeout);
    return http.Response.fromStream(streamed);
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
