import '../entities/app_settings.dart';

/// Application settings: read the whole document, write one group at a time.
///
/// Rules the implementation enforces before anything leaves the device,
/// because the server can only answer with a rejection:
///
/// * an email, phone, website, currency or hex colour that is filled in has to
///   be well formed,
/// * tax is a percentage, and the booking numbers have to be inside sane
///   bounds,
/// * an upload has to be a supported image, under the size cap.
abstract class SettingsRepository {
  /// `GET /settings`
  Future<AppSettings> getSettings();

  /// `GET /settings/{key}`
  Future<SettingValue> getSettingByKey(String key);

  /// `PUT /settings/general`
  Future<AppSettings> updateGeneralSettings(GeneralSettings settings);

  /// `PUT /settings/booking`
  Future<AppSettings> updateBookingSettings(BookingSettings settings);

  /// `PUT /settings/payment`
  Future<AppSettings> updatePaymentSettings(PaymentSettings settings);

  /// `PUT /settings/notifications`
  Future<AppSettings> updateNotificationSettings(NotificationSettings settings);

  /// `PUT /settings/branding`
  Future<AppSettings> updateBranding(BrandingSettings settings);

  /// `POST /settings/upload-logo` — returns the stored URL.
  Future<String> uploadLogo(String filePath, {String? filename});

  /// `POST /settings/upload-favicon` — returns the stored URL.
  Future<String> uploadFavicon(String filePath, {String? filename});

  /// `POST /settings/reset` — restores the defaults and answers with them.
  Future<AppSettings> resetSettings();
}