import '../../../core/utils/app_logger.dart';

/// Console tracing for the employee dashboard.
///
/// Mirrors `CoachLog` and `AdminLog` so one `flutter run` console shows the
/// whole path of an action: UI intent → controller state → repository → data
/// source → the raw HTTP exchange (which [AppLogger] already prints from inside
/// `ApiClient`).
///
/// Output rides on [AppLogger], which redacts tokens and passwords and stays
/// silent in release builds unless the build opts in with
/// `--dart-define=ENABLE_API_LOGS=true`. Bookings, payments and the user list
/// are all personal data, so this deliberately never uses a bare `print`.
class EmployeeLog {
  const EmployeeLog._();

  static const String _name = 'EMPLOYEE';

  /// A user-visible intent: a tap, a filter change, a sheet opening.
  static void ui(String message) =>
      AppLogger.debug('🖱️  $message', name: _name);

  /// A controller state transition.
  static void state(String message) =>
      AppLogger.debug('🧭 $message', name: _name);

  /// A repository/data-source call about to go out.
  static void call(String message) =>
      AppLogger.debug('📡 $message', name: _name);

  /// A call that came back, summarised by shape rather than by body.
  static void data(String message) =>
      AppLogger.debug('📦 $message', name: _name);

  /// A completed write.
  static void success(String message) =>
      AppLogger.debug('✅ $message', name: _name);

  /// Something the UI has to explain to the user.
  static void failure(String message, {Object? error, StackTrace? stackTrace}) =>
      AppLogger.error(
        message,
        name: _name,
        error: error,
        stackTrace: stackTrace,
      );

  /// A widget lifecycle marker — useful when chasing an unwanted rebuild.
  static void life(String message) =>
      AppLogger.debug('🌱 $message', name: _name);
}
