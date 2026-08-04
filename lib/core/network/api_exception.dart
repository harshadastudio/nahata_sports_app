import '../config/api_config.dart';

/// Base type for every failure surfaced by the network layer.
///
/// Screens can catch [ApiException] and show `e.message` directly — it is
/// always a user-presentable sentence.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors, this.cause});

  final String message;
  final int? statusCode;

  /// Field-level validation errors, when the server sends them.
  final Map<String, dynamic>? errors;

  final Object? cause;

  /// True when retrying the same request could plausibly succeed.
  bool get isRetryable => false;

  @override
  String toString() => message;
}

/// 400 — malformed request.
class BadRequestException extends ApiException {
  const BadRequestException(super.message, {super.errors, super.cause})
    : super(statusCode: 400);
}

/// 401 — token missing/expired/rejected. Triggers the refresh flow.
class UnauthorizedException extends ApiException {
  const UnauthorizedException(
    super.message, {
    super.errors,
    super.cause,
    this.sessionExpired = false,
  }) : super(statusCode: 401);

  /// Set when refresh failed and the user must sign in again.
  final bool sessionExpired;
}

/// 403 — authenticated but not permitted.
class ForbiddenException extends ApiException {
  const ForbiddenException(super.message, {super.errors, super.cause})
    : super(statusCode: 403);
}

/// 404 — resource missing.
class NotFoundException extends ApiException {
  const NotFoundException(super.message, {super.errors, super.cause})
    : super(statusCode: 404);
}

/// 409 — conflicting state (duplicate booking, already registered, …).
class ConflictException extends ApiException {
  const ConflictException(super.message, {super.errors, super.cause})
    : super(statusCode: 409);
}

/// 422 — semantic validation failure.
class ValidationException extends ApiException {
  const ValidationException(super.message, {super.errors, super.cause})
    : super(statusCode: 422);

  /// First field error, handy for inline form messages.
  String? get firstError {
    final map = errors;
    if (map == null || map.isEmpty) return null;
    final value = map.values.first;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value?.toString();
  }
}

/// 429 — throttled.
class RateLimitException extends ApiException {
  const RateLimitException(
    super.message, {
    super.errors,
    super.cause,
    this.retryAfter,
  }) : super(statusCode: 429);

  final Duration? retryAfter;

  @override
  bool get isRetryable => true;
}

/// 5xx — server side failure.
class ServerException extends ApiException {
  const ServerException(super.message, {super.statusCode, super.cause});

  @override
  bool get isRetryable => true;
}

/// No route to host / DNS failure / airplane mode.
class NoInternetException extends ApiException {
  const NoInternetException({super.cause}) : super(AuthMessages.noInternet);

  @override
  bool get isRetryable => true;
}

/// Connect or receive timeout.
class RequestTimeoutException extends ApiException {
  const RequestTimeoutException({super.cause}) : super(AuthMessages.timeout);

  @override
  bool get isRetryable => true;
}

/// Body was not the JSON shape we expected.
class ParseException extends ApiException {
  const ParseException(super.message, {super.cause});
}

/// Anything not covered above.
class UnknownApiException extends ApiException {
  const UnknownApiException({String? message, super.cause})
    : super(message ?? AuthMessages.unknown);
}
