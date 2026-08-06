import 'dart:io';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_remote_data_source.dart';
import '../models/app_settings_model.dart';

/// [SettingsRepository] over the JWT backend.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({SettingsRemoteDataSource? remote})
    : _remote = remote ?? SettingsRemoteDataSource();

  final SettingsRemoteDataSource _remote;

  @override
  Future<AppSettings> getSettings() async {
    final response = await _remote.all();
    if (!response.isOk) throw response.toException();

    final settings = AppSettingsMapper.fromJson(response.data);
    if (settings.raw.isEmpty) {
      // Says which kind of empty this was, and names the keys it did see, so a
      // mapper fix is one edit away.
      final keys = response.data is Map
          ? (response.data as Map).keys.toList()
          : const [];
      AdminLog.data(
        'The settings response carried no document. Top-level keys: $keys',
      );
    }

    AdminLog.data('Settings → $settings');
    return settings;
  }

  @override
  Future<SettingValue> getSettingByKey(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Name the setting to read.');
    }

    final response = await _remote.byKey(trimmed);
    if (!response.isOk) throw response.toException();

    final value = AppSettingsMapper.valueFrom(response.data, key: trimmed);
    AdminLog.data('Setting → $value');
    return value;
  }

  @override
  Future<AppSettings> updateGeneralSettings(GeneralSettings settings) async {
    final body = settings.toJson();

    if ((body['appName'] as String).isEmpty) {
      throw const ValidationException('Enter the app name.');
    }
    if ((body['companyName'] as String).isEmpty) {
      throw const ValidationException('Enter the company name.');
    }

    // The optional contact fields are only checked when they carry something —
    // a blank one is a cleared field, not a malformed one.
    final email = body['email'] as String;
    if (email.isNotEmpty && !SettingsValidation.isEmail(email)) {
      throw const ValidationException('Enter a valid email address.');
    }
    final phone = body['phone'] as String;
    if (phone.isNotEmpty && !SettingsValidation.isPhone(phone)) {
      throw const ValidationException(
        'The phone number must be exactly 10 digits.',
      );
    }
    final website = body['website'] as String;
    if (website.isNotEmpty && !SettingsValidation.isWebsite(website)) {
      throw const ValidationException('Enter a valid website address.');
    }

    return _write(() => _remote.updateGeneral(body), what: 'general settings');
  }

  @override
  Future<AppSettings> updateBookingSettings(BookingSettings settings) async {
    final body = settings.toJson();

    final advance = body['maxAdvanceBookingDays'] as int?;
    if (advance == null) {
      throw const ValidationException('Enter how far ahead customers may book.');
    }
    if (advance < 1 || advance > SettingsValidation.maxAdvanceDaysLimit) {
      throw ValidationException(
        'Advance booking must be between 1 and '
        '${SettingsValidation.maxAdvanceDaysLimit} days.',
      );
    }

    final cancellation = body['bookingCancellationHours'] as int?;
    if (cancellation == null) {
      throw const ValidationException(
        'Enter how long before a slot it may be cancelled.',
      );
    }
    if (cancellation < 0 ||
        cancellation > SettingsValidation.maxCancellationHoursLimit) {
      throw ValidationException(
        'The cancellation window must be between 0 and '
        '${SettingsValidation.maxCancellationHoursLimit} hours.',
      );
    }

    final slot = body['slotDuration'] as int?;
    if (slot == null) {
      throw const ValidationException('Enter the slot length.');
    }
    if (slot < SettingsValidation.minSlotMinutes ||
        slot > SettingsValidation.maxSlotMinutes) {
      throw ValidationException(
        'A slot must be between ${SettingsValidation.minSlotMinutes} and '
        '${SettingsValidation.maxSlotMinutes} minutes.',
      );
    }

    return _write(() => _remote.updateBooking(body), what: 'booking settings');
  }

  @override
  Future<AppSettings> updatePaymentSettings(PaymentSettings settings) async {
    final body = settings.toJson();

    final currency = body['currency'] as String;
    if (currency.isEmpty) {
      throw const ValidationException('Enter the currency code.');
    }
    if (!SettingsValidation.isCurrency(currency)) {
      throw const ValidationException(
        'Use a three-letter currency code, such as INR.',
      );
    }

    final tax = body['taxPercentage'] as num?;
    if (tax == null) {
      throw const ValidationException('Enter the tax percentage.');
    }
    if (tax < 0 || tax > 100) {
      throw const ValidationException('Tax must be between 0 and 100 percent.');
    }

    return _write(() => _remote.updatePayment(body), what: 'payment settings');
  }

  @override
  Future<AppSettings> updateNotificationSettings(
    NotificationSettings settings,
  ) {
    return _write(
      () => _remote.updateNotifications(settings.toJson()),
      what: 'notification settings',
    );
  }

  @override
  Future<AppSettings> updateBranding(BrandingSettings settings) async {
    final body = settings.toJson();

    // `toJson` normalises a good colour and blanks a bad one, so an empty
    // string here means the admin typed something that is not a colour.
    if ((body['primaryColor'] as String).isEmpty &&
        (settings.primaryColor ?? '').trim().isNotEmpty) {
      throw const ValidationException(
        'The primary colour must be a hex value such as #1976D2.',
      );
    }
    if ((body['secondaryColor'] as String).isEmpty &&
        (settings.secondaryColor ?? '').trim().isNotEmpty) {
      throw const ValidationException(
        'The secondary colour must be a hex value such as #FFC107.',
      );
    }

    return _write(() => _remote.updateBranding(body), what: 'branding');
  }

  @override
  Future<String> uploadLogo(String filePath, {String? filename}) =>
      _upload(SettingsImageKind.logo, filePath, filename: filename);

  @override
  Future<String> uploadFavicon(String filePath, {String? filename}) =>
      _upload(SettingsImageKind.favicon, filePath, filename: filename);

  @override
  Future<AppSettings> resetSettings() async {
    final response = await _remote.reset();
    if (!response.isOk) throw response.toException();

    AdminLog.success('Settings reset to their defaults');

    // The route may answer with the fresh document or with nothing; an empty
    // answer is reported as empty so the caller knows to re-read.
    return AppSettingsMapper.fromJson(response.data);
  }

  Future<String> _upload(
    SettingsImageKind kind,
    String filePath, {
    String? filename,
  }) async {
    if (filePath.trim().isEmpty) {
      throw ValidationException('Pick a ${kind.label.toLowerCase()} to upload.');
    }

    if (!SettingsValidation.isSupportedImage(filePath)) {
      throw ValidationException(
        'Use a ${SettingsValidation.allowedImageExtensions.join(', ')} image.',
      );
    }

    // Checked here rather than only in the picker: a large file would other-
    // wise be uploaded in full before the server refused it.
    final file = File(filePath);
    if (await file.exists()) {
      final bytes = await file.length();
      if (bytes > SettingsValidation.maxImageBytes) {
        throw ValidationException(
          'That image is larger than '
          '${SettingsValidation.maxImageMegabytes}MB.',
        );
      }
    }

    final response = await _remote.uploadImage(
      kind: kind,
      filePath: filePath,
      filename: filename,
    );
    if (!response.isOk) throw response.toException();

    final url = AppSettingsMapper.uploadedUrlFrom(response.data);
    if (url == null || url.isEmpty) {
      // Without a URL there is nothing to put in the branding payload, so this
      // is a failure even though the HTTP call succeeded.
      throw ServerException(
        'The ${kind.label.toLowerCase()} uploaded but the server did not '
        'return its URL.',
      );
    }

    AdminLog.success('Uploaded ${kind.label.toLowerCase()}');
    return url;
  }

  /// Runs a group write and reads whatever document came back.
  ///
  /// The write routes are documented without a response shape, so an answer
  /// that carries no document is reported as empty and the controller re-reads
  /// `GET /settings` — rather than a half-filled record being merged into the
  /// screen.
  Future<AppSettings> _write(
    Future<ApiResponse> Function() send, {
    required String what,
  }) async {
    final response = await send();
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated $what');
    return AppSettingsMapper.fromJson(response.data);
  }
}