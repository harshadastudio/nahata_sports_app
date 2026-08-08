import '../services/app_session.dart';
import 'api_role.dart';

/// The one venue a COMPLEX_ADMIN session is bound to.
///
/// Read from the authenticated session (`data.user.sportComplexId` /
/// `data.user.sportComplex`) — never a constant, and never a value picked in
/// the UI. `sportComplexId = 1` appears nowhere in the app.
///
/// This is a **usability and correctness** guard, not a security boundary: the
/// backend decides what a token may read. What it prevents is a venue admin
/// being offered another complex in a dropdown, or a filter chip that would
/// send them a 403.
///
/// Note the deliberate fail-open: an account with `COMPLEX_ADMIN` but no
/// complex on the session is *not* scoped here. Locking such a session to "no
/// venue" would render an empty console for a server-side misconfiguration the
/// user cannot fix, and the backend still refuses anything it should.
class ComplexScope {
  const ComplexScope._();

  /// True when the signed-in session is limited to a single venue.
  static bool get isActive =>
      ApiRole.current.isComplexAdmin && AppSession.instance.hasComplexScope;

  /// The venue id to scope to, or null when the session sees them all.
  static int? get id => isActive ? AppSession.instance.sportComplexId : null;

  /// "Sinhagad Road", or an empty string when unscoped.
  static String get name => isActive ? AppSession.instance.sportComplexName : '';

  /// Forces a complex filter to the session's venue.
  ///
  /// A scoped console cannot choose another complex, so whatever the caller
  /// asked for is replaced; an unscoped one keeps its own choice, including
  /// "All".
  static int? pin(int? requested) => isActive ? id : requested;

  /// Narrows a list to the session's venue.
  ///
  /// [complexIdOf] reads the venue from a row. A row that does not report one
  /// is **kept**: the server already answered within the token's scope, and
  /// dropping rows over a field the payload happens not to carry would hide
  /// real data. Where the venue is the row's own identity — the sports-complex
  /// catalogue — that case does not arise.
  static List<T> restrict<T>(List<T> rows, int? Function(T row) complexIdOf) {
    final venue = id;
    if (venue == null) return rows;

    return rows.where((row) {
      final rowVenue = complexIdOf(row);
      return rowVenue == null || rowVenue == venue;
    }).toList(growable: false);
  }
}