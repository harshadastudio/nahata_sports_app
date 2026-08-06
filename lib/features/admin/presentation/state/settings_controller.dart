import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'view_state.dart';

/// The five groups on the Settings page, in the order they are shown.
///
/// Saving is tracked per section rather than for the page as a whole: each
/// group is its own route, so only the card that was submitted should show a
/// spinner and only its button should be disabled.
enum SettingsSection {
  general('General'),
  booking('Booking'),
  payment('Payment'),
  notifications('Notifications'),
  branding('Branding');

  const SettingsSection(this.label);

  final String label;
}

/// Everything the Settings page needs: the document, per-section saving, the
/// two uploads and the reset.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository) {
    AdminLog.life('SettingsController created');
  }

  final SettingsRepository _repository;

  ViewState _state = ViewState.idle;
  AppSettings _settings = const AppSettings();
  String? _error;

  int _requestId = 0;
  bool _disposed = false;

  /// The section currently being written, if any.
  SettingsSection? _saving;

  /// The image currently being uploaded, if any.
  SettingsImageKind? _uploading;

  bool _resetting = false;

  // --- Reads -----------------------------------------------------------------

  ViewState get state => _state;
  AppSettings get settings => _settings;
  String? get error => _error;

  GeneralSettings get general => _settings.general;
  BookingSettings get booking => _settings.booking;
  PaymentSettings get payment => _settings.payment;
  NotificationSettings get notifications => _settings.notifications;
  BrandingSettings get branding => _settings.branding;

  SettingsSection? get savingSection => _saving;
  SettingsImageKind? get uploadingImage => _uploading;
  bool get isResetting => _resetting;

  bool get isFirstLoad => _state.isLoading && _settings.raw.isEmpty;
  bool get isRefreshing => _state.isLoading && _settings.raw.isNotEmpty;

  bool isSaving(SettingsSection section) => _saving == section;

  bool isUploading(SettingsImageKind kind) => _uploading == kind;

  /// True while anything is in flight — used to hold the destructive actions
  /// back rather than to disable the whole page.
  bool get isBusy =>
      _saving != null || _uploading != null || _resetting || _state.isLoading;

  // --- Loading ---------------------------------------------------------------

  Future<void> load() async {
    final id = ++_requestId;

    AdminLog.state('Settings loading');
    _state = ViewState.loading;
    _error = null;
    _safeNotify();

    try {
      final result = await _repository.getSettings();
      if (_disposed || id != _requestId) {
        AdminLog.state('Settings response superseded — dropped');
        return;
      }

      _settings = result;
      _state = ViewState.ready;
      AdminLog.state('Settings ready → $result');
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = error.message;
      AdminLog.failure('Settings load failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      _state = ViewState.failed;
      _error = 'Could not load settings. Please try again.';
      AdminLog.failure(
        'Settings load crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> refresh() {
    AdminLog.ui('Settings refresh requested');
    return load();
  }

  /// `GET /settings/{key}` — one value, without disturbing the page's state.
  ///
  /// Reads through the loaded document first: it already holds every group, so
  /// a value that is on screen does not need a round trip.
  Future<SettingValue> valueFor(String key, {bool refresh = false}) async {
    if (!refresh) {
      final local = _settings.valueFor(key);
      if (local != null) {
        AdminLog.data('Setting $key served from the loaded document');
        return SettingValue(key: key, value: local);
      }
    }

    AdminLog.ui('Reading setting $key');
    return _repository.getSettingByKey(key);
  }

  // --- Writes ----------------------------------------------------------------

  Future<void> saveGeneral(GeneralSettings settings) {
    return _save(
      SettingsSection.general,
      () => _repository.updateGeneralSettings(settings),
    );
  }

  Future<void> saveBooking(BookingSettings settings) {
    return _save(
      SettingsSection.booking,
      () => _repository.updateBookingSettings(settings),
    );
  }

  Future<void> savePayment(PaymentSettings settings) {
    return _save(
      SettingsSection.payment,
      () => _repository.updatePaymentSettings(settings),
    );
  }

  Future<void> saveNotifications(NotificationSettings settings) {
    return _save(
      SettingsSection.notifications,
      () => _repository.updateNotificationSettings(settings),
    );
  }

  Future<void> saveBranding(BrandingSettings settings) {
    return _save(
      SettingsSection.branding,
      () => _repository.updateBranding(settings),
    );
  }

  /// Uploads an image and writes the returned URL into branding.
  ///
  /// The upload route only stores the file; branding is what points at it, so
  /// the two are done together — otherwise a successful upload would leave the
  /// old logo on the storefront.
  Future<String> uploadImage({
    required SettingsImageKind kind,
    required String filePath,
    String? filename,
  }) async {
    if (_uploading != null) {
      throw const ConflictException('An upload is already in progress.');
    }

    AdminLog.ui('Uploading ${kind.label.toLowerCase()}');
    _uploading = kind;
    _error = null;
    _safeNotify();

    try {
      final url = kind == SettingsImageKind.logo
          ? await _repository.uploadLogo(filePath, filename: filename)
          : await _repository.uploadFavicon(filePath, filename: filename);

      if (_disposed) return url;

      // Shown straight away, so the preview is the uploaded image rather than
      // the local file — and the branding save below only has to confirm it.
      _settings = _settings.copyWith(
        branding: kind == SettingsImageKind.logo
            ? _settings.branding.copyWith(logo: url)
            : _settings.branding.copyWith(favicon: url),
      );
      _safeNotify();

      await _save(
        SettingsSection.branding,
        () => _repository.updateBranding(_settings.branding),
      );

      return url;
    } finally {
      if (!_disposed) {
        _uploading = null;
        _safeNotify();
      }
    }
  }

  /// `POST /settings/reset`, then a re-read so the screen shows the defaults
  /// the server actually applied.
  Future<void> reset() async {
    if (_resetting) return;

    AdminLog.ui('Reset settings confirmed');
    _resetting = true;
    _error = null;
    _safeNotify();

    try {
      final restored = await _repository.resetSettings();
      if (_disposed) return;

      if (restored.raw.isNotEmpty) {
        _settings = restored;
        _state = ViewState.ready;
        _safeNotify();
      }
    } finally {
      if (!_disposed) {
        _resetting = false;
        _safeNotify();
      }
    }

    // Always re-read: the reset route is documented without a response body,
    // and the page must not be left showing what was there before.
    await load();
  }

  /// Runs a group write, then makes the screen agree with the server.
  ///
  /// Throws on failure so the form that submitted can stay open and explain
  /// itself — the page shows the snackbar, the card shows the field errors.
  Future<void> _save(
    SettingsSection section,
    Future<AppSettings> Function() send,
  ) async {
    if (_saving == section) return;

    AdminLog.ui('Saving ${section.label.toLowerCase()} settings');
    _saving = section;
    _error = null;
    _safeNotify();

    try {
      final updated = await send();
      if (_disposed) return;

      if (updated.raw.isNotEmpty) {
        // The route echoed the document — no second round trip needed.
        _settings = updated;
        _state = ViewState.ready;
        _safeNotify();
      } else {
        // It did not, so the screen is refreshed from `GET /settings` rather
        // than left showing what the form happened to hold.
        _saving = null;
        await load();
      }
    } finally {
      if (!_disposed) {
        _saving = null;
        _safeNotify();
      }
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AdminLog.life('SettingsController disposed');
    super.dispose();
  }
}