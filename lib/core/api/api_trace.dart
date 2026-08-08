import '../config/api_config.dart';
import '../services/app_session.dart';
import '../utils/app_logger.dart';
import 'api_role.dart';
import 'role_api_map.dart';

/// Role-aware API tracing.
///
/// Answers the question a role-mapped app makes hard to eyeball: *which* API
/// did this screen just call, and as whom?
///
/// ```
/// [API] ROLE: COMPLEX_ADMIN
/// [API] MODULE: COACHES
/// [API] SPORT COMPLEX ID: 1
/// ➡️ GET https://api.nahatasports.com/api/coaches?page=1&limit=100
/// ⬅️ 200 https://api.nahatasports.com/api/coaches?page=1&limit=100 (184ms)
/// ```
///
/// [context] is emitted by `ApiClient` immediately before it logs the request
/// itself, so **every** call gets these lines — lists, details, creates and
/// deletes alike — without a single call site having to tag itself. The module
/// is recovered from the URL by [RoleApiMap.moduleForPath].
///
/// Output rides on [AppLogger]: debug builds only unless a release build opts
/// in with `--dart-define=ENABLE_API_LOGS=true`, and redacted throughout.
/// Access tokens, refresh tokens and passwords are never part of a line here —
/// only the role, the module and the venue id are printed, and the request line
/// that follows has its headers and body redacted by [AppLogger].
class ApiTrace {
  const ApiTrace._();

  static const String _name = 'API';

  /// The three context lines for a request to [path].
  ///
  /// [module] can be passed when the caller knows it; otherwise it is inferred
  /// from the path, and omitted entirely when the path belongs to no console
  /// module (`/auth/*`, the storefront) rather than printed as a guess.
  static void context(String path, {ApiModule? module, ApiRole? role}) {
    if (!AppLogger.enabled) return;

    final effective = role ?? ApiRole.current;
    _line('ROLE: ${effective.wire}');

    final resolved = module ?? RoleApiMap.moduleForPath(path);
    if (resolved != null) _line('MODULE: ${resolved.traceName}');

    // Printed only when the session actually is venue-scoped, so an ADMIN trace
    // does not carry a meaningless "SPORT COMPLEX ID: null".
    final complexId = AppSession.instance.sportComplexId;
    if (complexId != null && effective == ApiRole.complexAdmin) {
      _line('SPORT COMPLEX ID: $complexId');
    }
  }

  /// The absolute URL a relative [path] resolves to.
  static String url(String path, [Map<String, dynamic>? query]) {
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final normalised = path.startsWith('/') ? path : '/$path';

    final entries = (query ?? const <String, dynamic>{}).entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');

    return entries.isEmpty ? '$base$normalised' : '$base$normalised?$entries';
  }

  static void _line(String message) =>
      AppLogger.debug('[API] $message', name: _name);
}