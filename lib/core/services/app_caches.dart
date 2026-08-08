import '../../repositories/sports_complex_repository.dart';
import '../utils/app_logger.dart';
import 'selected_ground.dart';

/// Everything cached for the lifetime of a *session* rather than the process.
///
/// Tokens, the profile and the permission matrix are wiped by
/// `AuthRepository.clearSession`. This is the rest: catalogues and selections
/// held in singletons that would otherwise outlive a sign-out, because a
/// singleton does not know the user changed.
///
/// It matters most between the two administrative roles. An ADMIN warms the
/// venue catalogue with every complex in the estate; if a COMPLEX_ADMIN then
/// signs in on the same running app, an unwiped cache would hand their venue
/// picker the whole estate — the exact leak this clears.
///
/// Register anything new here rather than clearing it at the call site, so
/// "what survives a sign-out?" has one answer.
class AppCaches {
  const AppCaches._();

  /// Drops every session-scoped cache. Safe to call more than once, and safe
  /// to call when nobody is signed in.
  static Future<void> clear() async {
    // The venue catalogue: estate-wide for an ADMIN, one venue for a
    // COMPLEX_ADMIN, and the source for every complex picker in the app.
    SportsComplexRepository.instance.invalidateCache();

    // The venue the user was browsing. It is persisted, so without this it
    // would survive not just the sign-out but the app restart, and the next
    // account would open on the previous one's ground.
    await SelectedGround.instance.clear();

    AppLogger.debug('Session caches cleared', name: 'Auth');
  }
}