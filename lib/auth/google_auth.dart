import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../core/utils/app_logger.dart';

/// Google sign-in, client side only.
///
/// The ID token this returns is handed to `POST /auth/google-login`
/// (`AuthRepository.googleLogin`) as `credential` — the backend verifies it
/// against Google. The app never trusts it on its own.
class GoogleAuthService {
  /// Web client id — this is the `aud` the backend verifies the ID token
  /// against. Lives in Google Cloud project **501667050692**.
  static const String _serverClientId =
      '501667050692-mcu5dljf0r6h2i9o3dbap4hvatgakr9i.apps.googleusercontent.com';

  /// iOS OAuth client id, for bundle `com.nahata.nahataApp`.
  ///
  /// This MUST live in the same project as [_serverClientId] (501667050692),
  /// otherwise Google rejects sign-in with
  /// `invalid_audience: The audience client and the client need to be in the
  /// same project.`
  ///
  /// It is passed explicitly because the iOS plugin would otherwise fall back
  /// to `CLIENT_ID` in GoogleService-Info.plist, which belongs to the Firebase
  /// project (966021820270) and is the wrong project. Android needs no
  /// equivalent: it resolves its client from package name + SHA-1 instead.
  static const String _iosClientId =
      '501667050692-28p5a5j28ntbfp7ma1fl46fhdcv191iv.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _serverClientId,
    clientId: (!kIsWeb && (Platform.isIOS || Platform.isMacOS))
        ? _iosClientId
        : null,
  );

  static Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      // Clean previous session (safe)
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account =
      await _googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth =
      await account.authentication;

      // 🚨 Critical check — without this the backend has nothing to verify.
      // A null id token almost always means `serverClientId` above does not
      // match the Web client id registered for this project.
      if (auth.idToken == null) {
        AppLogger.error('Google sign-in returned no ID token', name: 'Auth');
        return null;
      }

      // The id token is a credential — log that one arrived, never its value.
      AppLogger.debug('Google sign-in ok for ${account.email}', name: 'Auth');

      // ✅ JUST RETURN DATA → BACKEND WILL VERIFY
      return {
        "idToken": auth.idToken,
        "email": account.email,
        "name": account.displayName,
        "photo": account.photoUrl,
      };
    } catch (e) {
      AppLogger.error('Google sign-in failed', name: 'Auth', error: e);
      return null;
    }
  }
}
// class GoogleAuthService {
//   static final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: ['email', 'profile'],
//
//     serverClientId: '501667050692-mcu5dljf0r6h2i9o3dbap4hvatgakr9i.apps.googleusercontent.com',
//     forceCodeForRefreshToken: true,
//
//   );
//
//
//   static Future<Map<String, dynamic>?> signInWithGoogle() async    {
//     try {
//       // 🔥 Always try to sign out old sessions first
//       try {
//         await _googleSignIn.signOut();
//         await _googleSignIn.disconnect();
//
//       } catch (e) {
//         print("⚠ Ignore disconnect error: $e");
//       }
//
//       // 🔥 Force popup to appear
//       final account = await _googleSignIn.signIn();
//       if (account == null) return null;
//
//       final auth = await account.authentication;
//
//       print("🪪 ID Token: ${auth.idToken}");
//       print("🔑 Access Token: ${auth.accessToken}");
//
//       // Verify token from Google
//       final response = await http.get(Uri.parse(
//           "https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=${auth.idToken}"
//       ));
//
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         print("✅ Google Verified: $data");
//
//         return {
//           "idToken": auth.idToken,
//           "accessToken": auth.accessToken,
//           "email": account.email,
//           "name": account.displayName,
//           "photo": account.photoUrl,
//         };
//       } else {
//         print("❌ Token invalid: ${response.body}");
//         return null;
//       }
//     } catch (e) {
//       print("❌ Google Sign-In Fatal Error: $e");
//       return null;
//     }
//   }
// }