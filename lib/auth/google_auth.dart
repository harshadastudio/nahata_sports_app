import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],

    serverClientId: '501667050692-mcu5dljf0r6h2i9o3dbap4hvatgakr9i.apps.googleusercontent.com',
    forceCodeForRefreshToken: true,

  );


  static Future<Map<String, dynamic>?> signInWithGoogle() async    {
    try {
      // 🔥 Always try to sign out old sessions first
      try {
        await _googleSignIn.signOut();
        await _googleSignIn.disconnect();

      } catch (e) {
        print("⚠ Ignore disconnect error: $e");
      }

      // 🔥 Force popup to appear
      final account = await _googleSignIn.signIn();
      if (account == null) return null;

      final auth = await account.authentication;

      print("🪪 ID Token: ${auth.idToken}");
      print("🔑 Access Token: ${auth.accessToken}");

      // Verify token from Google
      final response = await http.get(Uri.parse(
          "https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=${auth.idToken}"
      ));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("✅ Google Verified: $data");

        return {
          "idToken": auth.idToken,
          "accessToken": auth.accessToken,
          "email": account.email,
          "name": account.displayName,
          "photo": account.photoUrl,
        };
      } else {
        print("❌ Token invalid: ${response.body}");
        return null;
      }
    } catch (e) {
      print("❌ Google Sign-In Fatal Error: $e");
      return null;
    }
  }
}