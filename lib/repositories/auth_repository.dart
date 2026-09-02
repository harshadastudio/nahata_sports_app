import 'dart:io';

import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/services/app_caches.dart';
import '../core/services/permission_service.dart';
import '../core/storage/profile_cache.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/app_logger.dart';
import '../models/profile_model.dart';

/// Result of a login attempt. Carries the parsed profile on success and a
/// user-presentable message on failure.
class AuthResult {
  const AuthResult._({
    required this.success,
    this.profile,
    this.message,
    this.exception,
  });

  const AuthResult.success(ProfileModel profile)
    : this._(success: true, profile: profile);

  const AuthResult.failure(String message, {ApiException? exception})
    : this._(success: false, message: message, exception: exception);

  final bool success;
  final ProfileModel? profile;
  final String? message;
  final ApiException? exception;
}

/// Result of `POST /students/register`.
class RegistrationResult {
  const RegistrationResult({
    required this.success,
    this.message,
    this.user,
    this.student,
    this.errors,
  });

  final bool success;

  /// Server message — "Student registered successfully." or the reason.
  final String? message;

  /// `data.user` — id, name, email, phone_number, role, status, avatar…
  final Map<String, dynamic>? user;

  /// `data.student` — the student record created alongside the user.
  final Map<String, dynamic>? student;

  /// Field-level validation errors, when the server sends them.
  final Map<String, dynamic>? errors;

  /// First field error, for showing under the offending input.
  String? get firstFieldError {
    final map = errors;
    if (map == null || map.isEmpty) return null;
    final value = map.values.first;
    if (value is List && value.isNotEmpty) return value.first.toString();
    return value?.toString();
  }
}

/// All authentication + profile network access lives here. Screens and
/// providers talk to this class, never to [ApiClient] directly.
class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  final ApiClient _api = ApiClient.instance;
  final TokenStorage _tokens = TokenStorage.instance;
  final ProfileCache _cache = ProfileCache.instance;

  // ---------------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------------

  Future<bool> get hasSession => _tokens.hasSession;

  /// `POST /auth/login`
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // A sign-in starts a new session, and the account may be a different one
    // with a different role and a different scope. Anything the previous
    // session cached goes first, so no ADMIN list can be showing when a
    // COMPLEX_ADMIN's console builds.
    await AppCaches.clear();

    try {
      final response = await _api.post(
        ApiEndpoints.login,
        requiresAuth: false,
        body: {'email': email, 'password': password},
      );

      if (!response.isOk) {
        return AuthResult.failure(
          response.message ?? 'Login failed. Please try again.',
        );
      }

      final payload = response.payload;

      await _tokens.saveTokens(
        accessToken: _text(payload['accessToken'] ?? payload['token']),
        refreshToken: _text(payload['refreshToken']),
      );

      final userJson = response.objectAt('user') ?? payload;
      final profile = ProfileModel.fromJson(
        Map<String, dynamic>.from(userJson),
      );

      await _cache.save(profile);
      PermissionService.instance.sync(profile);

      AppLogger.debug(
        'Login succeeded for role ${profile.roleLabel}',
        name: 'Auth',
      );
      return AuthResult.success(profile);
    } on ApiException catch (e) {
      AppLogger.error('Login failed', name: 'Auth', error: e.message);
      return AuthResult.failure(e.message, exception: e);
    } catch (e, s) {
      AppLogger.error('Login error', name: 'Auth', error: e, stackTrace: s);
      return AuthResult.failure(AuthMessages.unknown);
    }
  }

  /// `POST /auth/register` — quick sign-up.
  ///
  /// The response carries `accessToken` and `refreshToken` beside the new
  /// user, so a successful sign-up **is** a signed-in session: the tokens are
  /// stored and the profile cached exactly as [login] does, and the caller can
  /// route straight into the app without asking for the password again.
  ///
  /// The `data.user` it returns is a thin one — id, name, email, role, phone —
  /// with no `permissions`. `/auth/profile` is therefore re-read straight
  /// after, so the session ends up with the same permission set a login would
  /// have produced. A failure there is not fatal: the account exists and the
  /// tokens are valid, and the next profile refresh will fill the gap.
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if (trimmedName.isEmpty) {
      throw const ValidationException('Enter your name.');
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(trimmedEmail)) {
      throw const ValidationException('Enter a valid email address.');
    }
    if (digits.length != 10) {
      throw const ValidationException(
        'The phone number must be exactly 10 digits.',
      );
    }
    if (password.length < 6) {
      throw const ValidationException(
        'The password must be at least 6 characters.',
      );
    }

    try {
      final response = await _api.post(
        ApiEndpoints.register,
        requiresAuth: false,
        body: {
          'name': trimmedName,
          'email': trimmedEmail,
          'password': password,
          'phone_number': digits,
        },
      );

      if (!response.isOk) {
        return AuthResult.failure(
          response.message ?? 'Sign up failed. Please try again.',
        );
      }

      final payload = response.payload;

      await _tokens.saveTokens(
        accessToken: _text(payload['accessToken'] ?? payload['token']),
        refreshToken: _text(payload['refreshToken']),
      );

      final userJson = response.objectAt('user') ?? payload;
      var profile = ProfileModel.fromJson(Map<String, dynamic>.from(userJson));

      await _cache.save(profile);
      PermissionService.instance.sync(profile);

      // The permissions the sign-up response leaves out.
      try {
        profile = await fetchProfile();
      } on ApiException catch (e) {
        AppLogger.debug(
          'Signed up, but the profile read failed: ${e.message}',
          name: 'Auth',
        );
      }

      AppLogger.debug('Sign up succeeded for $trimmedEmail', name: 'Auth');
      return AuthResult.success(profile);
    } on ApiException catch (e) {
      AppLogger.error('Sign up failed', name: 'Auth', error: e.message);
      return AuthResult.failure(e.message, exception: e);
    } catch (e, s) {
      AppLogger.error('Sign up error', name: 'Auth', error: e, stackTrace: s);
      return AuthResult.failure(AuthMessages.unknown);
    }
  }

  /// `POST /auth/google-login`
  ///
  /// [credential] is the Google **ID token** (`GoogleSignInAuthentication
  /// .idToken`), which the backend verifies — the app never trusts it itself.
  /// [portal] tells the backend which front-end the sign-in came from; the web
  /// app sends `"main"`.
  ///
  /// Returns the same [AuthResult] as [login], so the session it establishes is
  /// indistinguishable from a password login: tokens in secure storage, profile
  /// cached, permissions synced.
  Future<AuthResult> googleLogin({
    required String credential,
    String portal = 'main',
  }) async {
    // Same reason as [login]: a new session must not inherit the last one's
    // caches.
    await AppCaches.clear();

    try {
      final response = await _api.post(
        ApiEndpoints.googleLogin,
        requiresAuth: false,
        body: {'credential': credential, 'portal': portal},
      );

      if (!response.isOk) {
        return AuthResult.failure(
          response.message ?? 'Google login failed. Please try again.',
        );
      }

      final payload = response.payload;

      await _tokens.saveTokens(
        accessToken: _text(payload['accessToken'] ?? payload['token']),
        refreshToken: _text(payload['refreshToken']),
      );

      final userJson = response.objectAt('user') ?? payload;
      final profile = ProfileModel.fromJson(
        Map<String, dynamic>.from(userJson),
      );

      await _cache.save(profile);
      PermissionService.instance.sync(profile);

      AppLogger.debug(
        'Google login succeeded for role ${profile.roleLabel}'
        '${profile.needsPhone ? ' (phone number still needed)' : ''}',
        name: 'Auth',
      );
      return AuthResult.success(profile);
    } on ApiException catch (e) {
      AppLogger.error('Google login failed', name: 'Auth', error: e.message);
      return AuthResult.failure(e.message, exception: e);
    } catch (e, s) {
      AppLogger.error(
        'Google login error',
        name: 'Auth',
        error: e,
        stackTrace: s,
      );
      return AuthResult.failure(AuthMessages.unknown);
    }
  }

  /// `POST /auth/apple-login`
  ///
  /// [identityToken] is the JWT from `AuthorizationCredentialAppleID
  /// .identityToken`, which the backend verifies against Apple's public keys —
  /// the app never trusts it itself. It expires roughly ten minutes after
  /// Apple issues it, and a stale one comes back as the same `401 Apple
  /// authentication failed` as a forged one, so it must be sent straight away.
  ///
  /// [firstName] / [lastName] are only populated on the user's **first ever**
  /// authorization; Apple never sends the name again, not even inside the
  /// token. They are forwarded when present and omitted otherwise — the server
  /// keeps the name it already stored and will not overwrite it.
  ///
  /// The email may be a `@privaterelay.appleid.com` alias, or absent entirely,
  /// when the user chose *Hide My Email*. That is fine: the account is keyed on
  /// Apple's stable `sub`, and an existing Nahata account with the same email
  /// is linked rather than duplicated.
  ///
  /// Returns the same [AuthResult] as [login] and [googleLogin], so the session
  /// is indistinguishable from a password login. On a fresh Apple account
  /// `profile.needsPhone` is true — Apple never provides a phone number, and
  /// booking confirmations cannot be delivered without one.
  Future<AuthResult> appleLogin({
    required String identityToken,
    String? firstName,
    String? lastName,
    String portal = 'main',
  }) async {
    // Same reason as [login]: a new session must not inherit the last one's
    // caches.
    await AppCaches.clear();

    final first = firstName?.trim();
    final last = lastName?.trim();
    final hasName =
        (first != null && first.isNotEmpty) ||
        (last != null && last.isNotEmpty);

    try {
      final response = await _api.post(
        ApiEndpoints.appleLogin,
        requiresAuth: false,
        body: {
          'identityToken': identityToken,
          // First authorization only. Sending `{"name": {}}` on later logins
          // would be a pointless overwrite attempt, so the key is dropped.
          if (hasName)
            'user': {
              'name': {
                if (first != null && first.isNotEmpty) 'firstName': first,
                if (last != null && last.isNotEmpty) 'lastName': last,
              },
            },
          // `admin` is reserved for the admin panel and answers 403 here.
          'portal': portal,
        },
      );

      if (!response.isOk) {
        return AuthResult.failure(
          response.message ?? 'Apple login failed. Please try again.',
        );
      }

      final payload = response.payload;

      await _tokens.saveTokens(
        accessToken: _text(payload['accessToken'] ?? payload['token']),
        refreshToken: _text(payload['refreshToken']),
      );

      final userJson = response.objectAt('user') ?? payload;
      final profile = ProfileModel.fromJson(
        Map<String, dynamic>.from(userJson),
      );

      await _cache.save(profile);
      PermissionService.instance.sync(profile);

      AppLogger.debug(
        'Apple login succeeded for role ${profile.roleLabel}'
        '${profile.needsPhone ? ' (phone number still needed)' : ''}',
        name: 'Auth',
      );
      return AuthResult.success(profile);
    } on ApiException catch (e) {
      AppLogger.error('Apple login failed', name: 'Auth', error: e.message);
      return AuthResult.failure(e.message, exception: e);
    } catch (e, s) {
      AppLogger.error(
        'Apple login error',
        name: 'Auth',
        error: e,
        stackTrace: s,
      );
      return AuthResult.failure(AuthMessages.unknown);
    }
  }

  /// `POST /students/register`
  ///
  /// Mandatory: [name], [phone], [email], [sportComplexId], [password] and
  /// [confirmPassword]. Everything else is optional.
  ///
  /// When [avatarPath] is set the request goes out as multipart so the photo
  /// is uploaded with the form; otherwise it is plain JSON.
  Future<RegistrationResult> register({
    required String name,
    required String phone,
    required String email,
    required int sportComplexId,
    required String password,
    required String confirmPassword,
    String? dob,
    String? gender,
    String? bloodGroup,
    String? referralCode,
    String? avatarPath,
  }) async {
    // Keys mirror the `data.user` object the endpoint returns.
    final fields = <String, String>{
      'name': name.trim(),
      'email': email.trim(),
      'phone_number': phone.trim(),
      'password': password,
      'confirmPassword': confirmPassword,
      'sportComplexId': sportComplexId.toString(),
      if (dob != null && dob.isNotEmpty) 'dob': dob,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (bloodGroup != null && bloodGroup.isNotEmpty)
        'blood_group': bloodGroup,
      if (referralCode != null && referralCode.isNotEmpty)
        'referral_code': referralCode,
    };

    try {
      final response = avatarPath == null || avatarPath.isEmpty
          ? await _api.post(
              ApiEndpoints.registerStudent,
              requiresAuth: false,
              body: <String, dynamic>{
                ...fields,
                'sportComplexId': sportComplexId,
              },
            )
          : await _api.multipart(
              ApiEndpoints.registerStudent,
              requiresAuth: false,
              fields: fields,
              files: [UploadFile(field: 'avatar', path: avatarPath)],
            );

      if (!response.isOk) {
        return RegistrationResult(
          success: false,
          message: response.message ?? 'Registration failed. Please try again.',
        );
      }

      final payload = response.payload;
      final user = payload['user'];
      final student = payload['student'];

      AppLogger.debug('Registered ${_text(email)}', name: 'Auth');

      return RegistrationResult(
        success: true,
        message: response.message ?? 'Registered successfully',
        user: user is Map ? Map<String, dynamic>.from(user) : null,
        student: student is Map ? Map<String, dynamic>.from(student) : null,
      );
    } on ApiException catch (e) {
      AppLogger.error('Registration failed', name: 'Auth', error: e.message);
      return RegistrationResult(
        success: false,
        message: e.message,
        errors: e.errors,
      );
    } catch (e, s) {
      AppLogger.error(
        'Registration error',
        name: 'Auth',
        error: e,
        stackTrace: s,
      );
      return const RegistrationResult(
        success: false,
        message: AuthMessages.unknown,
      );
    }
  }

  /// `GET /auth/profile`
  ///
  /// Throws an [ApiException] on failure so callers can decide between
  /// "show cached data" and "surface the error".
  Future<ProfileModel> fetchProfile() async {
    final response = await _api.get(ApiEndpoints.profile);

    final userJson = response.objectAt('user') ?? response.payload;
    if (userJson.isEmpty) {
      throw const ParseException('Profile response did not contain a user.');
    }

    final profile = ProfileModel.fromJson(Map<String, dynamic>.from(userJson));
    await _cache.save(profile);
    PermissionService.instance.sync(profile);
    return profile;
  }

  /// `PUT /auth/profile` — the four fields the endpoint accepts.
  ///
  /// Body: `{name, phone_number, gender, blood_group}`. Nothing else is sent;
  /// the endpoint ignores unknown keys, and sending a field it does not own
  /// (email, status, dob) would imply an edit that never takes.
  ///
  /// A null argument means "leave this alone" and is omitted from the body,
  /// so a screen that edits only the blood group does not blank the gender.
  ///
  /// The response carries the updated user twice — at the top level and again
  /// under `data` — so [ApiResponse.objectAt] finds it either way. The result
  /// is cached and pushed through [PermissionService] exactly like a fresh
  /// [fetchProfile], which is what makes Home, More and the dashboards pick up
  /// the new name without a manual reload.
  Future<ProfileModel> updateProfile({
    String? name,
    String? phoneNumber,
    String? gender,
    String? bloodGroup,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (phoneNumber != null) 'phone_number': phoneNumber.trim(),
      if (gender != null) 'gender': gender.trim(),
      if (bloodGroup != null) 'blood_group': bloodGroup.trim(),
    };

    if (body.isEmpty) {
      throw const ValidationException('There is nothing to update.');
    }

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    final trimmedName = body['name'] as String?;
    if (trimmedName != null && trimmedName.isEmpty) {
      throw const ValidationException('Enter your name.');
    }

    final phone = body['phone_number'] as String?;
    if (phone != null && phone.replaceAll(RegExp(r'\D'), '').length != 10) {
      throw const ValidationException(
        'The phone number must be exactly 10 digits.',
      );
    }

    final response = await _api.put(ApiEndpoints.profile, body: body);
    if (!response.isOk) throw response.toException();

    final userJson = response.objectAt('user') ?? response.payload;
    if (userJson.isEmpty) {
      throw const ParseException(
        'The profile was updated but the server did not return it.',
      );
    }

    final profile = ProfileModel.fromJson(Map<String, dynamic>.from(userJson));
    await _cache.save(profile);
    PermissionService.instance.sync(profile);

    AppLogger.debug('Profile updated (${body.keys.join(', ')})', name: 'Auth');
    return profile;
  }

  /// `POST /auth/profile/picture` — multipart, field `profile_picture`.
  ///
  /// The one route that writes the signed-in user's photo. `PUT /auth/profile`
  /// carries the text fields and ignores a file, which is why the edit form
  /// used to show the picture as read-only.
  ///
  /// The reply is `{data: {url}}`. That URL is written onto the cached profile
  /// and pushed through [PermissionService] the same way [updateProfile] does,
  /// so Home, More and the dashboards repaint without re-fetching. When the
  /// reply omits the URL the profile is re-read instead of guessed at, so the
  /// caller always ends up with what the server actually stored.
  ///
  /// [imagePath] must point at a file of at most
  /// [ApiConfig.maxProfilePictureBytes]; a larger one is rejected here rather
  /// than sent, because the server's own refusal arrives as a bare 413.
  Future<ProfileModel> uploadProfilePicture(String imagePath) async {
    final file = File(imagePath);

    if (!await file.exists()) {
      throw const ValidationException('That image could not be read.');
    }

    final bytes = await file.length();
    if (bytes > ApiConfig.maxProfilePictureBytes) {
      throw const ValidationException(
        'That picture is too large. Please choose one under 1 MB.',
      );
    }

    final response = await _api.multipart(
      ApiEndpoints.profilePicture,
      files: [UploadFile(field: 'profile_picture', path: imagePath)],
    );

    if (!response.isOk) throw response.toException();

    // `{data: {url}}` on the documented path; a couple of aliases because the
    // same field reaches the app as `profile_picture` elsewhere in the API.
    final data = response.objectAt('data') ?? response.payload;
    final url = _resolveMediaUrl(
      _text(data['url'] ?? data['profile_picture'] ?? data['avatar']),
    );

    if (url == null || url.isEmpty) {
      // The upload succeeded but told us nothing — ask for the truth rather
      // than leave the old photo on screen.
      AppLogger.debug(
        'Picture uploaded but no URL returned — re-reading profile',
        name: 'Auth',
      );
      return fetchProfile();
    }

    final current = await _cache.read() ?? await fetchProfile();
    final profile = current.copyWith(profilePicture: url, avatar: url);

    await _cache.save(profile);
    PermissionService.instance.sync(profile);

    AppLogger.debug('Profile picture updated', name: 'Auth');
    return profile;
  }

  /// `PUT /auth/change-password` — `{currentPassword, newPassword}`.
  ///
  /// The backend requires at least 6 characters and answers 403 for the roles
  /// whose password an administrator owns (staff logins and complex admins),
  /// with the message to show them. Both are surfaced as typed exceptions the
  /// caller can present, not swallowed.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw const ValidationException('Enter your current password.');
    }
    if (newPassword.length < 6) {
      throw const ValidationException(
        'Your new password must be at least 6 characters.',
      );
    }
    if (newPassword == currentPassword) {
      throw const ValidationException(
        'Your new password must be different from the current one.',
      );
    }

    final response = await _api.put(
      ApiEndpoints.changePassword,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );

    if (!response.isOk) throw response.toException();

    AppLogger.debug('Password changed', name: 'Auth');
    return response.message ?? 'Your password has been changed.';
  }

  /// `POST /auth/forgot-password` — `{email}`, no session needed.
  ///
  /// The endpoint answers 200 whenever an email was supplied, deliberately not
  /// revealing whether an account exists, so the caller should show the same
  /// "check your inbox" either way rather than treating it as confirmation.
  Future<String> forgotPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Enter your email address.');
    }

    final response = await _api.post(
      ApiEndpoints.forgotPassword,
      requiresAuth: false,
      body: {'email': trimmed},
    );

    if (!response.isOk) throw response.toException();
    return response.message ??
        'If that email is registered, a reset link is on its way.';
  }

  /// `POST /auth/reset-password` — `{token, newPassword}`, no session needed.
  ///
  /// [token] is the one from the emailed link, not an access token.
  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    if (token.trim().isEmpty) {
      throw const ValidationException('That reset link is not valid.');
    }
    if (newPassword.length < 6) {
      throw const ValidationException(
        'Your new password must be at least 6 characters.',
      );
    }

    final response = await _api.post(
      ApiEndpoints.resetPassword,
      requiresAuth: false,
      body: {'token': token.trim(), 'newPassword': newPassword},
    );

    if (!response.isOk) throw response.toException();
    return response.message ?? 'Your password has been reset.';
  }

  /// Profile from disk/memory — instant, no network.
  Future<ProfileModel?> cachedProfile() => _cache.read();

  /// `POST /auth/logout`, then [clearSession].
  ///
  /// The call goes out first, while the access token is still available, and a
  /// failure never blocks the local sign-out — the user must end up signed out
  /// either way.
  Future<bool> logout() async {
    var acknowledged = false;

    try {
      if (await _tokens.hasSession) {
        final response = await _api.post(ApiEndpoints.logout);
        acknowledged = response.isOk;
        AppLogger.debug(
          acknowledged
              ? 'Server logout: ${response.message ?? 'ok'}'
              : 'Server logout returned not-ok: ${response.message}',
          name: 'Auth',
        );
      }
    } on ApiException catch (e) {
      // An expired token is a perfectly good reason for this to fail.
      AppLogger.debug('Server logout failed: ${e.message}', name: 'Auth');
    } catch (e) {
      AppLogger.error('Server logout error', name: 'Auth', error: e);
    }

    await clearSession();
    return acknowledged;
  }

  /// Clears every trace of the session: tokens, cached profile, permissions
  /// and the legacy preference keys the older screens wrote.
  Future<void> clearSession() async {
    await _tokens.clear();
    await _cache.clear();
    PermissionService.instance.clear();

    // Role, permissions and the assigned complex go with the profile above.
    // This drops what a singleton would otherwise carry into the next session —
    // the venue catalogue and the selected ground — so an ADMIN's data cannot
    // surface in a COMPLEX_ADMIN's console, or the other way round.
    await AppCaches.clear();

    AppLogger.debug('Session cleared', name: 'Auth');
  }

  // ---------------------------------------------------------------------------
  // Push tokens (legacy backend)
  // ---------------------------------------------------------------------------

  Future<void> registerFcmToken({
    required int userId,
    required String fcmToken,
    required String platform,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.saveFcmToken,
        baseUrl: ApiConfig.legacyBaseUrl,
        requiresAuth: false,
        body: {'user_id': userId, 'fcm_token': fcmToken, 'platform': platform},
      );
      AppLogger.debug('FCM token registered', name: 'Push');
    } catch (e) {
      // Push registration must never block sign-in.
      AppLogger.error('FCM register failed', name: 'Push', error: e);
    }
  }

  Future<void> unregisterFcmToken({
    required int userId,
    required String fcmToken,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.deleteFcmToken,
        baseUrl: ApiConfig.legacyBaseUrl,
        requiresAuth: false,
        body: {'user_id': userId, 'fcm_token': fcmToken},
      );
      AppLogger.debug('FCM token removed', name: 'Push');
    } catch (e) {
      AppLogger.error('FCM unregister failed', name: 'Push', error: e);
    }
  }

  /// Absolute URL for a photo the API may have returned as a path.
  ///
  /// The web client renders the value straight into an `<img src>`, so a
  /// root-relative path resolves against the site host there and would simply
  /// fail to load here. Anything already absolute is returned untouched.
  static String? _resolveMediaUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    final host = ApiConfig.attendanceBaseUrl.endsWith('/')
        ? ApiConfig.attendanceBaseUrl.substring(
            0,
            ApiConfig.attendanceBaseUrl.length - 1,
          )
        : ApiConfig.attendanceBaseUrl;

    return url.startsWith('/') ? '$host$url' : '$host/$url';
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
