import '../../domain/entities/app_settings.dart';
import 'json_reader.dart';

/// Maps `/settings` JSON onto [AppSettings].
///
/// `GET /settings` is documented only by the shape of the five write bodies,
/// so this reads two layouts without preferring either: the grouped document
/// (`{general: {...}, booking: {...}}`) that mirrors the write routes, and a
/// flat one where every key sits at the top level. Whichever the backend
/// sends, the same fields come out.
class AppSettingsMapper {
  const AppSettingsMapper._();

  static AppSettings fromJson(Object? body) {
    final root = _payload(body);
    if (root.isEmpty) return const AppSettings();

    return AppSettings(
      general: generalFrom(_group(root, const ['general', 'app', 'company'])),
      booking: bookingFrom(_group(root, const ['booking', 'bookings'])),
      payment: paymentFrom(_group(root, const ['payment', 'payments'])),
      notifications: notificationsFrom(
        _group(root, const ['notifications', 'notification']),
      ),
      branding: brandingFrom(
        _group(root, const ['branding', 'brand', 'appearance', 'theme']),
      ),
      raw: root,
    );
  }

  static GeneralSettings generalFrom(Map<String, dynamic> json) {
    return GeneralSettings(
      appName: JsonReader.string(json, const ['appName', 'app_name']),
      companyName: JsonReader.string(json, const [
        'companyName',
        'company_name',
        'businessName',
      ]),
      email: JsonReader.string(json, const [
        'email',
        'contactEmail',
        'contact_email',
      ]),
      phone: JsonReader.string(json, const [
        'phone',
        'phoneNumber',
        'phone_number',
        'contactPhone',
      ]),
      address: JsonReader.string(json, const ['address', 'companyAddress']),
      website: JsonReader.string(json, const ['website', 'websiteUrl', 'url']),
    );
  }

  static BookingSettings bookingFrom(Map<String, dynamic> json) {
    return BookingSettings(
      maxAdvanceBookingDays: JsonReader.integer(json, const [
        'maxAdvanceBookingDays',
        'max_advance_booking_days',
        'advanceBookingDays',
      ]),
      bookingCancellationHours: JsonReader.integer(json, const [
        'bookingCancellationHours',
        'booking_cancellation_hours',
        'cancellationHours',
      ]),
      slotDuration: JsonReader.integer(json, const [
        'slotDuration',
        'slot_duration',
        'slotDurationMinutes',
      ]),
      allowOnlineBooking: JsonReader.boolean(json, const [
        'allowOnlineBooking',
        'allow_online_booking',
        'onlineBooking',
      ]),
    );
  }

  static PaymentSettings paymentFrom(Map<String, dynamic> json) {
    return PaymentSettings(
      currency: JsonReader.string(json, const ['currency', 'currencyCode']),
      taxPercentage: _number(json, const [
        'taxPercentage',
        'tax_percentage',
        'tax',
        'gst',
      ]),
      razorpayKey: JsonReader.string(json, const [
        'razorpayKey',
        'razorpay_key',
        'razorpayKeyId',
      ]),
      allowCashPayment: JsonReader.boolean(json, const [
        'allowCashPayment',
        'allow_cash_payment',
        'cashPayment',
      ]),
    );
  }

  static NotificationSettings notificationsFrom(Map<String, dynamic> json) {
    return NotificationSettings(
      emailNotifications: JsonReader.boolean(json, const [
        'emailNotifications',
        'email_notifications',
        'email',
      ]),
      smsNotifications: JsonReader.boolean(json, const [
        'smsNotifications',
        'sms_notifications',
        'sms',
      ]),
      pushNotifications: JsonReader.boolean(json, const [
        'pushNotifications',
        'push_notifications',
        'push',
      ]),
    );
  }

  static BrandingSettings brandingFrom(Map<String, dynamic> json) {
    return BrandingSettings(
      primaryColor: JsonReader.string(json, const [
        'primaryColor',
        'primary_color',
        'primary',
      ]),
      secondaryColor: JsonReader.string(json, const [
        'secondaryColor',
        'secondary_color',
        'secondary',
      ]),
      logo: JsonReader.string(json, const ['logo', 'logoUrl', 'logo_url']),
      favicon: JsonReader.string(json, const [
        'favicon',
        'faviconUrl',
        'favicon_url',
      ]),
    );
  }

  /// Reads `GET /settings/{key}`.
  ///
  /// The route is documented without a response shape, so three are accepted:
  /// the bare value, `{value: …}`, and `{key: …, value: …}`.
  static SettingValue valueFrom(Object? body, {required String key}) {
    final payload = body is Map ? Map<String, dynamic>.from(body) : null;
    if (payload == null) {
      return SettingValue(key: key, value: body);
    }

    final data = payload['data'];

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final value = JsonReader.pick(map, const ['value', 'setting']) ??
          map[key] ??
          (map.length == 1 ? map.values.first : null);
      return SettingValue(key: key, value: value ?? map, raw: map);
    }

    if (data != null) return SettingValue(key: key, value: data, raw: payload);

    final value =
        JsonReader.pick(payload, const ['value', 'setting']) ?? payload[key];
    return SettingValue(key: key, value: value, raw: payload);
  }

  /// The URL an upload route answered with.
  static String? uploadedUrlFrom(Object? body) {
    if (body is String) return body.trim().isEmpty ? null : body.trim();
    if (body is! Map) return null;

    final map = Map<String, dynamic>.from(body);
    const keys = [
      'url',
      'logo',
      'favicon',
      'logoUrl',
      'faviconUrl',
      'path',
      'imageUrl',
      'image',
      'location',
      'secure_url',
    ];

    final direct = JsonReader.string(map, keys);
    if (direct != null) return direct;

    final data = map['data'];
    if (data is String) return data.trim().isEmpty ? null : data.trim();
    if (data is Map) {
      return JsonReader.string(Map<String, dynamic>.from(data), keys);
    }
    return null;
  }

  /// The settings document inside the response envelope.
  static Map<String, dynamic> _payload(Object? body) {
    if (body is! Map) return const {};

    final map = Map<String, dynamic>.from(body);
    final data = map['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      // `{data: {settings: {...}}}` — one more envelope than usual.
      final settings = inner['settings'];
      if (settings is Map) return Map<String, dynamic>.from(settings);
      return inner;
    }

    // A list of `{key, value}` rows is the other way a settings table is
    // commonly served; it is folded into a document so the rest of the mapper
    // does not have to care which it was.
    if (data is List) return _fold(data);

    final settings = map['settings'];
    if (settings is Map) return Map<String, dynamic>.from(settings);

    return map;
  }

  static Map<String, dynamic> _fold(List<dynamic> rows) {
    final result = <String, dynamic>{};
    for (final row in rows) {
      if (row is! Map) continue;
      final map = Map<String, dynamic>.from(row);
      final key = JsonReader.string(map, const ['key', 'name', 'settingKey']);
      if (key == null) continue;
      result[key] = map['value'] ?? map['settingValue'];
    }
    return result;
  }

  /// A group of the document, falling back to the document itself so a flat
  /// payload reads exactly as well as a grouped one.
  static Map<String, dynamic> _group(
    Map<String, dynamic> root,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = root[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return root;
  }

  static num? _number(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value;
    // Money and percentages come back as decimal strings on this backend.
    return num.tryParse(value.toString().trim());
  }
}