/// The five settings groups, and the whole document they make up.
///
/// `GET /settings` answers with all of them; each group is written back
/// through its own route, which is why they are separate types rather than one
/// flat record — a save only ever sends the group that was edited.

/// Who the business is (`PUT /settings/general`).
class GeneralSettings {
  const GeneralSettings({
    this.appName,
    this.companyName,
    this.email,
    this.phone,
    this.address,
    this.website,
  });

  final String? appName;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? address;
  final String? website;

  GeneralSettings copyWith({
    String? appName,
    String? companyName,
    String? email,
    String? phone,
    String? address,
    String? website,
  }) {
    return GeneralSettings(
      appName: appName ?? this.appName,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      website: website ?? this.website,
    );
  }

  /// The documented body, in full.
  ///
  /// Every key travels even when empty: this is a `PUT` of the whole group, so
  /// an omitted field would read as "leave it alone" when the admin actually
  /// cleared it.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'appName': (appName ?? '').trim(),
      'companyName': (companyName ?? '').trim(),
      'email': (email ?? '').trim(),
      'phone': (phone ?? '').trim(),
      'address': (address ?? '').trim(),
      'website': (website ?? '').trim(),
    };
  }

  @override
  String toString() => 'GeneralSettings($appName, $companyName, $email)';
}

/// How bookings behave (`PUT /settings/booking`).
class BookingSettings {
  const BookingSettings({
    this.maxAdvanceBookingDays,
    this.bookingCancellationHours,
    this.slotDuration,
    this.allowOnlineBooking,
  });

  /// How far ahead a customer may book.
  final int? maxAdvanceBookingDays;

  /// How long before the slot a booking may still be cancelled.
  final int? bookingCancellationHours;

  /// The length of one slot, in minutes.
  final int? slotDuration;

  final bool? allowOnlineBooking;

  BookingSettings copyWith({
    int? maxAdvanceBookingDays,
    int? bookingCancellationHours,
    int? slotDuration,
    bool? allowOnlineBooking,
  }) {
    return BookingSettings(
      maxAdvanceBookingDays:
          maxAdvanceBookingDays ?? this.maxAdvanceBookingDays,
      bookingCancellationHours:
          bookingCancellationHours ?? this.bookingCancellationHours,
      slotDuration: slotDuration ?? this.slotDuration,
      allowOnlineBooking: allowOnlineBooking ?? this.allowOnlineBooking,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'maxAdvanceBookingDays': maxAdvanceBookingDays,
      'bookingCancellationHours': bookingCancellationHours,
      'slotDuration': slotDuration,
      'allowOnlineBooking': allowOnlineBooking ?? false,
    };
  }

  @override
  String toString() =>
      'BookingSettings(advance: $maxAdvanceBookingDays, '
      'cancel: $bookingCancellationHours, slot: $slotDuration, '
      'online: $allowOnlineBooking)';
}

/// What customers are charged, and how (`PUT /settings/payment`).
class PaymentSettings {
  const PaymentSettings({
    this.currency,
    this.taxPercentage,
    this.razorpayKey,
    this.allowCashPayment,
  });

  /// ISO code — `INR`.
  final String? currency;

  final num? taxPercentage;

  /// The publishable key only. A secret would never be sent to a client.
  final String? razorpayKey;

  final bool? allowCashPayment;

  PaymentSettings copyWith({
    String? currency,
    num? taxPercentage,
    String? razorpayKey,
    bool? allowCashPayment,
  }) {
    return PaymentSettings(
      currency: currency ?? this.currency,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      razorpayKey: razorpayKey ?? this.razorpayKey,
      allowCashPayment: allowCashPayment ?? this.allowCashPayment,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'currency': (currency ?? '').trim().toUpperCase(),
      'taxPercentage': taxPercentage,
      'razorpayKey': (razorpayKey ?? '').trim(),
      'allowCashPayment': allowCashPayment ?? false,
    };
  }

  @override
  String toString() =>
      'PaymentSettings($currency, tax: $taxPercentage, cash: $allowCashPayment)';
}

/// Which channels the system may use (`PUT /settings/notifications`).
class NotificationSettings {
  const NotificationSettings({
    this.emailNotifications,
    this.smsNotifications,
    this.pushNotifications,
  });

  final bool? emailNotifications;
  final bool? smsNotifications;
  final bool? pushNotifications;

  NotificationSettings copyWith({
    bool? emailNotifications,
    bool? smsNotifications,
    bool? pushNotifications,
  }) {
    return NotificationSettings(
      emailNotifications: emailNotifications ?? this.emailNotifications,
      smsNotifications: smsNotifications ?? this.smsNotifications,
      pushNotifications: pushNotifications ?? this.pushNotifications,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'emailNotifications': emailNotifications ?? false,
      'smsNotifications': smsNotifications ?? false,
      'pushNotifications': pushNotifications ?? false,
    };
  }

  @override
  String toString() =>
      'NotificationSettings(email: $emailNotifications, '
      'sms: $smsNotifications, push: $pushNotifications)';
}

/// How the product looks (`PUT /settings/branding`).
class BrandingSettings {
  const BrandingSettings({
    this.primaryColor,
    this.secondaryColor,
    this.logo,
    this.favicon,
  });

  /// `#RRGGBB` as the API writes it.
  final String? primaryColor;
  final String? secondaryColor;

  /// URLs, set by the two upload routes.
  final String? logo;
  final String? favicon;

  BrandingSettings copyWith({
    String? primaryColor,
    String? secondaryColor,
    String? logo,
    String? favicon,
  }) {
    return BrandingSettings(
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      logo: logo ?? this.logo,
      favicon: favicon ?? this.favicon,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'primaryColor': SettingsValidation.normaliseHex(primaryColor) ?? '',
      'secondaryColor': SettingsValidation.normaliseHex(secondaryColor) ?? '',
      'logo': (logo ?? '').trim(),
      'favicon': (favicon ?? '').trim(),
    };
  }

  @override
  String toString() =>
      'BrandingSettings($primaryColor / $secondaryColor, logo: '
      '${(logo ?? '').isEmpty ? 'none' : 'set'})';
}

/// Everything `GET /settings` returns.
class AppSettings {
  const AppSettings({
    this.general = const GeneralSettings(),
    this.booking = const BookingSettings(),
    this.payment = const PaymentSettings(),
    this.notifications = const NotificationSettings(),
    this.branding = const BrandingSettings(),
    this.raw = const {},
  });

  final GeneralSettings general;
  final BookingSettings booking;
  final PaymentSettings payment;
  final NotificationSettings notifications;
  final BrandingSettings branding;

  /// The untouched document, so a value the app has no field for is still
  /// reachable — and so [valueFor] can answer without another round trip.
  final Map<String, dynamic> raw;

  AppSettings copyWith({
    GeneralSettings? general,
    BookingSettings? booking,
    PaymentSettings? payment,
    NotificationSettings? notifications,
    BrandingSettings? branding,
    Map<String, dynamic>? raw,
  }) {
    return AppSettings(
      general: general ?? this.general,
      booking: booking ?? this.booking,
      payment: payment ?? this.payment,
      notifications: notifications ?? this.notifications,
      branding: branding ?? this.branding,
      raw: raw ?? this.raw,
    );
  }

  /// A single value out of the loaded document, by the key
  /// `GET /settings/{key}` would use. Null when it is not in there.
  Object? valueFor(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return null;

    final direct = raw[trimmed];
    if (direct != null) return direct;

    // The document is grouped, so `taxPercentage` lives under `payment`.
    for (final value in raw.values) {
      if (value is Map && value[trimmed] != null) return value[trimmed];
    }
    return null;
  }

  @override
  String toString() =>
      'AppSettings($general, $booking, $payment, $notifications, $branding)';
}

/// One value from `GET /settings/{key}`.
class SettingValue {
  const SettingValue({required this.key, this.value, this.raw = const {}});

  final String key;
  final Object? value;
  final Map<String, dynamic> raw;

  bool get isEmpty => value == null || value.toString().trim().isEmpty;

  String? get asString {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  int? get asInt {
    final current = value;
    if (current is int) return current;
    if (current is num) return current.toInt();
    return int.tryParse(current?.toString().trim() ?? '');
  }

  num? get asNumber {
    final current = value;
    if (current is num) return current;
    return num.tryParse(current?.toString().trim() ?? '');
  }

  bool? get asBool {
    final current = value;
    if (current is bool) return current;
    switch (current?.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
    return null;
  }

  @override
  String toString() => 'SettingValue($key: $value)';
}

/// Which image a settings upload is for.
///
/// The two routes take differently-named multipart fields, and that name is
/// the only thing that differs — so it lives with the endpoint rather than
/// being passed around as a bare string.
enum SettingsImageKind {
  logo('logo'),
  favicon('favicon');

  const SettingsImageKind(this.field);

  /// The multipart field name the route expects.
  final String field;

  String get label => this == SettingsImageKind.logo ? 'Logo' : 'Favicon';
}

/// The rules the forms and the repository both check against.
///
/// Kept in one place so a value can never pass the form and then be rejected
/// by the repository for a different reason.
class SettingsValidation {
  const SettingsValidation._();

  /// Image types the upload routes accept.
  static const List<String> allowedImageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
  ];

  /// The cap an upload is refused at, before it is sent.
  static const int maxImageBytes = 5 * 1024 * 1024;

  static const int maxImageMegabytes = 5;

  /// Sensible bounds for the booking numbers — a slot of 0 minutes or a year
  /// of advance booking is a typo, not a configuration.
  static const int maxAdvanceDaysLimit = 365;
  static const int maxCancellationHoursLimit = 720;
  static const int minSlotMinutes = 5;
  static const int maxSlotMinutes = 600;

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
  static final RegExp _hex = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3})$');
  static final RegExp _currency = RegExp(r'^[A-Za-z]{3}$');

  static bool isEmail(String? value) => _email.hasMatch((value ?? '').trim());

  /// Ten digits, the format every phone field in this app uses.
  static bool isPhone(String? value) =>
      (value ?? '').replaceAll(RegExp(r'\D'), '').length == 10;

  /// A website with or without its scheme — `nahatasports.com` is what an
  /// admin types, and refusing it would be pedantry.
  static bool isWebsite(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return false;

    final withScheme = text.contains('://') ? text : 'https://$text';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAuthority) return false;
    if (!uri.scheme.startsWith('http')) return false;
    return uri.host.contains('.');
  }

  static bool isCurrency(String? value) =>
      _currency.hasMatch((value ?? '').trim());

  static bool isHexColour(String? value) => _hex.hasMatch((value ?? '').trim());

  /// `#RRGGBB`, upper-cased — the shape the API documents. Null for anything
  /// that is not a colour, so a bad value is never sent as one.
  static String? normaliseHex(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (!isHexColour(text)) return null;

    var digits = text.startsWith('#') ? text.substring(1) : text;
    if (digits.length == 3) {
      // `#abc` → `#aabbcc`, so the API only ever sees the long form.
      digits = digits.split('').map((char) => '$char$char').join();
    }
    return '#${digits.toUpperCase()}';
  }

  static bool isSupportedImage(String path) {
    final lower = path.toLowerCase().split('?').first;
    return allowedImageExtensions.any((ext) => lower.endsWith('.$ext'));
  }
}