import '../../../core/utils/app_logger.dart';

/// Console tracing for the admin dashboard.
///
/// Every layer reports through here, so one `flutter run` console shows the
/// whole path of an action: UI intent → controller state → repository →
/// data source → the raw HTTP exchange (which [AppLogger] already prints from
/// inside `ApiClient`).
///
/// Output rides on [AppLogger], which means it is redacted (tokens, passwords
/// and `Authorization` headers are masked) and silent in release builds unless
/// the build opts in with `--dart-define=ENABLE_API_LOGS=true`. Printing an
/// admin's user list unconditionally into a shipped app's log would be a data
/// leak, so this deliberately does not use a bare `print`.
class AdminLog {
  const AdminLog._();

  static const String _name = 'ADMIN';

  /// A user-visible intent: a tap, a filter change, a dialog opening.
  static void ui(String message) =>
      AppLogger.debug('🖱️  $message', name: _name);

  /// A controller state transition.
  static void state(String message) =>
      AppLogger.debug('🧭 $message', name: _name);

  /// A repository/data-source call about to go out.
  static void call(String message) =>
      AppLogger.debug('📡 $message', name: _name);

  /// A call that came back, with a short shape summary rather than the body
  /// (`ApiClient` already prints the body).
  static void data(String message) =>
      AppLogger.debug('📦 $message', name: _name);

  /// A completed write.
  static void success(String message) =>
      AppLogger.debug('✅ $message', name: _name);

  /// Something the UI has to explain to the user.
  static void failure(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => AppLogger.error(
    message,
    name: _name,
    error: error,
    stackTrace: stackTrace,
  );

  /// A widget lifecycle marker — useful when chasing an unwanted rebuild.
  static void life(String message) =>
      AppLogger.debug('🌱 $message', name: _name);
}
