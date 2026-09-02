import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../core/utils/app_logger.dart';

/// Sign in with Apple, client side only.
///
/// The identity token this returns is handed to `POST /auth/apple-login`
/// (`AuthRepository.appleLogin`) as `identityToken` — the backend verifies it
/// against Apple's public keys. The app never trusts it on its own.
class AppleAuthService {
  const AppleAuthService._();

  /// Whether the button should be shown at all. Apple only offers the native
  /// sheet on iOS/macOS; the web/Service ID flow is the website's job.
  static bool get isAvailable =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  /// Runs the Apple sheet and returns what the backend needs.
  ///
  /// Returns `null` when the user cancels or Apple fails — the caller shows the
  /// message, since a cancel is not an error worth shouting about.
  ///
  /// The `firstName` / `lastName` keys are present **only on the user's first
  /// ever authorization** for this app. Apple never sends the name again, and
  /// it is not inside the token either, so it has to be forwarded on that one
  /// call or the account keeps the email prefix as its name forever.
  static Future<Map<String, String?>?> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;

      // Without this the backend has nothing to verify. In practice it means
      // the Sign in with Apple capability is missing from the app entitlements.
      if (identityToken == null || identityToken.isEmpty) {
        AppLogger.error(
          'Apple sign-in returned no identity token',
          name: 'Auth',
        );
        return null;
      }

      // The token is a credential — log that one arrived, never its value.
      // It is also short-lived (~10 minutes), so it goes to the backend now.
      AppLogger.debug(
        'Apple sign-in ok'
        '${credential.givenName != null ? ' (first authorization, name given)' : ''}',
        name: 'Auth',
      );

      return {
        'identityToken': identityToken,
        'firstName': credential.givenName,
        'lastName': credential.familyName,
        // May be null, or a `@privaterelay.appleid.com` alias if the user chose
        // *Hide My Email*. Informational only — the backend keys off Apple's
        // stable `sub`, not this.
        'email': credential.email,
        'userIdentifier': credential.userIdentifier,
      };
    } on SignInWithAppleAuthorizationException catch (e) {
      // Cancelled is the common path: the user tapped away from the sheet.
      if (e.code == AuthorizationErrorCode.canceled) {
        AppLogger.debug('Apple sign-in cancelled by the user', name: 'Auth');
      } else {
        AppLogger.error(
          'Apple sign-in failed (${e.code})',
          name: 'Auth',
          error: e.message,
        );
      }
      return null;
    } catch (e) {
      AppLogger.error('Apple sign-in failed', name: 'Auth', error: e);
      return null;
    }
  }
}
