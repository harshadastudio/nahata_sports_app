/// The paths the security console answers to.
///
/// The app routes by widget rather than by a central table, so these are the
/// canonical names for the console's sections — used for deep links, for the
/// section a login lands on, and so a path appears in exactly one place.
class SecurityRoutes {
  const SecurityRoutes._();

  /// Where a `SECURITY` account lands after signing in.
  static const String dashboard = '/security/dashboard';

  static const String visitorScanner = '/security/visitor';
  static const String eventScanner = '/security/event';
  static const String courtScanner = '/security/court';
  static const String coachingScanner = '/security/coaching';

  /// Every path the console owns.
  static const List<String> all = [
    dashboard,
    visitorScanner,
    eventScanner,
    courtScanner,
    coachingScanner,
  ];

  /// True when [route] belongs to the security console — the check a route
  /// guard makes before deciding whether this account may open it.
  static bool owns(String? route) => route != null && all.contains(route);
}