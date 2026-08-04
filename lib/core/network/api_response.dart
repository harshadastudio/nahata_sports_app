import 'dart:convert';

import 'api_exception.dart';

/// A decoded HTTP response.
///
/// [data] is the already-JSON-decoded body (`Map`, `List`, or `null` when the
/// body was empty/non-JSON). [raw] keeps the original text for diagnostics.
class ApiResponse {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    required this.raw,
    this.headers = const {},
  });

  final int statusCode;
  final dynamic data;
  final String raw;
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// The API wraps payloads as `{success: bool, message: String, data: {...}}`,
  /// while some legacy endpoints use `{status: bool, ...}`. Both are accepted.
  bool get isOk {
    final body = data;
    if (body is Map) {
      if (body['success'] is bool) return body['success'] as bool;
      if (body['status'] is bool) return body['status'] as bool;
    }
    return isSuccess;
  }

  String? get message {
    final body = data;
    if (body is Map && body['message'] != null)
      return body['message'].toString();
    return null;
  }

  /// The `data` envelope, or the whole body when the server does not wrap it.
  Map<String, dynamic> get payload {
    final body = data;
    if (body is Map<String, dynamic>) {
      final inner = body['data'];
      if (inner is Map<String, dynamic>) return inner;
      return body;
    }
    return const {};
  }

  /// Reads a nested object, e.g. `objectAt('user')` for `{ "user": {...} }`.
  /// Looks both at the top level and inside the `data` envelope.
  Map<String, dynamic>? objectAt(String key) {
    final body = data;
    if (body is! Map) return null;
    final direct = body[key];
    if (direct is Map<String, dynamic>) return direct;
    if (direct is Map) return Map<String, dynamic>.from(direct);
    final inner = body['data'];
    if (inner is Map) {
      final nested = inner[key];
      if (nested is Map<String, dynamic>) return nested;
      if (nested is Map) return Map<String, dynamic>.from(nested);
    }
    return null;
  }

  static ApiResponse parse({
    required int statusCode,
    required String body,
    Map<String, String> headers = const {},
  }) {
    dynamic decoded;
    if (body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        // Non-JSON body (HTML error page, empty 204, …) — keep it as raw text.
        decoded = null;
      }
    }
    return ApiResponse(
      statusCode: statusCode,
      data: decoded,
      raw: body,
      headers: headers,
    );
  }

  /// Extracts field-level errors from the common server shapes.
  Map<String, dynamic>? get validationErrors {
    final body = data;
    if (body is! Map) return null;
    final errors = body['errors'] ?? body['error'];
    if (errors is Map<String, dynamic>) return errors;
    if (errors is Map) return Map<String, dynamic>.from(errors);
    return null;
  }

  /// Maps a non-2xx (or `success:false`) response onto a typed exception.
  ApiException toException() {
    final serverMessage = message;
    final errors = validationErrors;

    switch (statusCode) {
      case 400:
        return BadRequestException(
          serverMessage ?? 'Invalid request.',
          errors: errors,
        );
      case 401:
        return UnauthorizedException(
          serverMessage ?? 'You are not authorised to perform this action.',
          errors: errors,
        );
      case 403:
        return ForbiddenException(
          serverMessage ?? 'You do not have permission to do this.',
          errors: errors,
        );
      case 404:
        return NotFoundException(
          serverMessage ?? 'The requested resource was not found.',
          errors: errors,
        );
      case 409:
        return ConflictException(
          serverMessage ?? 'This action conflicts with existing data.',
          errors: errors,
        );
      case 422:
        return ValidationException(
          serverMessage ?? 'Please check the details you entered.',
          errors: errors,
        );
      case 429:
        final retryAfter = headers['retry-after'];
        return RateLimitException(
          serverMessage ?? 'Too many requests. Please wait a moment.',
          errors: errors,
          retryAfter: retryAfter == null
              ? null
              : Duration(seconds: int.tryParse(retryAfter) ?? 0),
        );
    }

    if (statusCode >= 500) {
      return ServerException(
        serverMessage ?? 'Server is temporarily unavailable. Please try again.',
        statusCode: statusCode,
      );
    }

    return UnknownApiException(message: serverMessage);
  }
}
