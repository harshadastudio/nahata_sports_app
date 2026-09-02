import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/visitor_pass_code.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/visitor_pass_result_sheet.dart';

/// What the scanner does with a code it reads.
enum VisitorScanMode {
  /// `POST /visitor-passes/verify` with `scanType: In`.
  checkIn('Check in', Icons.login_rounded),

  /// `POST /visitor-passes/verify` with `scanType: Out`.
  checkOut('Check out', Icons.logout_rounded),

  /// `POST /visitor-passes/lookup` — reads the pass without changing it.
  lookup('Verify only', Icons.search_rounded);

  const VisitorScanMode(this.label, this.icon);

  final String label;
  final IconData icon;

  bool get isLookup => this == VisitorScanMode.lookup;

  VisitorScanType? get scanType {
    switch (this) {
      case VisitorScanMode.checkIn:
        return VisitorScanType.checkIn;
      case VisitorScanMode.checkOut:
        return VisitorScanType.checkOut;
      case VisitorScanMode.lookup:
        return null;
    }
  }
}

/// The gate screen: camera scanning, manual code entry, and the three things a
/// code can be used for.
///
/// The mode is switchable on the spot because one person works the gate for
/// both directions — and because "verify only" has to be one tap away when
/// somebody wants to check a pass without spending a leg of it.
class VisitorPassScannerPage extends StatefulWidget {
  const VisitorPassScannerPage({
    super.key,
    required this.onVerify,
    required this.onLookup,
    this.initialMode = VisitorScanMode.checkIn,
  });

  final Future<VisitorPassCheck> Function(String code, VisitorScanType type)
  onVerify;
  final Future<VisitorPassCheck> Function(String code) onLookup;

  final VisitorScanMode initialMode;

  /// Pushes the scanner, carrying the console's theme onto the new route — a
  /// pushed page builds outside the dashboard's own [Theme], so without this it
  /// would render in the customer app's colours.
  static Future<void> push(
    BuildContext context, {
    required Future<VisitorPassCheck> Function(
      String code,
      VisitorScanType type,
    )
    onVerify,
    required Future<VisitorPassCheck> Function(String code) onLookup,
    VisitorScanMode initialMode = VisitorScanMode.checkIn,
  }) {
    final theme = Theme.of(context);

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: theme,
          child: VisitorPassScannerPage(
            onVerify: onVerify,
            onLookup: onLookup,
            initialMode: initialMode,
          ),
        ),
      ),
    );
  }

  @override
  State<VisitorPassScannerPage> createState() => _VisitorPassScannerPageState();
}

class _VisitorPassScannerPageState extends State<VisitorPassScannerPage>
    with WidgetsBindingObserver {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'VisitorPassQR');
  final TextEditingController _manual = TextEditingController();

  QRViewController? _controller;

  late VisitorScanMode _mode;

  bool _cameraAllowed = false;
  bool _permissionChecked = false;
  bool _permanentlyDenied = false;
  bool _flashOn = false;

  /// True from the moment a code is accepted until the result has been dealt
  /// with — without it the camera stream would fire the same code many times a
  /// second and every one of them would hit `/verify`.
  bool _processing = false;

  /// The last code seen, so a QR left in front of the lens is not re-submitted
  /// the instant the sheet closes.
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mode = widget.initialMode;
    AdminLog.life('VisitorPassScannerPage mounted (${_mode.name})');
    _requestCamera();
  }

  /// The camera preview is a native view: on Android it has to be paused
  /// across a hot reload, and on iOS resumed, or it comes back black.
  @override
  void reassemble() {
    super.reassemble();
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      _controller?.pauseCamera();
    } else if (Platform.isIOS) {
      _controller?.resumeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The QRViewController disposes itself when the QRView unmounts — calling
    // it here as well is deprecated and would double-dispose the native view.
    _manual.dispose();
    AdminLog.life('VisitorPassScannerPage disposed');
    super.dispose();
  }

  bool get _cameraSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Re-checks the camera permission when the app comes back to the
  /// foreground.
  ///
  /// The denied state offers "Open settings", and without this the user grants
  /// the permission, returns, and still sees the same refusal until they leave
  /// the screen and come back — which reads as the grant not having worked.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && !_cameraAllowed) {
      _requestCamera();
    }
  }

  Future<void> _requestCamera() async {
    if (!_cameraSupported) {
      setState(() {
        _permissionChecked = true;
        _cameraAllowed = false;
      });
      return;
    }

    final status = await Permission.camera.request();
    if (!mounted) return;

    AdminLog.state('Camera permission → $status');
    setState(() {
      _permissionChecked = true;
      _cameraAllowed = status.isGranted || status.isLimited;
      _permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    AdminLog.state('QR view created');

    controller.scannedDataStream.listen((scanData) {
      final raw = scanData.code;
      if (raw == null || raw.trim().isEmpty) return;
      if (_processing) return;
      _handleScanned(raw);
    });
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.toggleFlash();
      final status = await controller.getFlashStatus();
      if (!mounted) return;
      setState(() => _flashOn = status ?? !_flashOn);
      AdminLog.ui('Torch → ${_flashOn ? 'on' : 'off'}');
    } catch (error) {
      // Not every device exposes a torch; failing to toggle it must not take
      // the scanner down.
      AdminLog.failure('Torch unavailable', error: error);
    }
  }

  Future<void> _handleScanned(String raw) async {
    final code = VisitorPassCode.extract(raw);

    if (code == null) {
      AdminLog.failure(
        'Unreadable QR: ${raw.length > 120 ? '${raw.substring(0, 120)}…' : raw}',
      );
      await _pauseCamera();
      if (!mounted) return;

      AdminFeedback.error(
        context,
        'That QR code is not a visitor pass. Try again, or type the code.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _resumeCamera();
      return;
    }

    if (code == _lastCode && _processing) return;

    await _submit(code, fromCamera: true);
  }

  Future<void> _submitManual() async {
    final code = VisitorPassCode.extract(_manual.text) ?? _manual.text.trim();
    if (code.isEmpty) {
      AdminFeedback.info(context, 'Enter the pass code first.');
      return;
    }
    FocusScope.of(context).unfocus();
    await _submit(code, fromCamera: false);
  }

  Future<void> _submit(String code, {required bool fromCamera}) async {
    if (_processing) return;

    setState(() {
      _processing = true;
      _lastCode = code;
    });

    if (fromCamera) {
      await _pauseCamera();
      // A short haptic is the confirmation the desk gets before the sheet
      // arrives — the phone is usually held at arm's length at a gate.
      unawaited(HapticFeedback.mediumImpact());
    }

    try {
      final scanType = _mode.scanType;

      final result = scanType == null
          ? await widget.onLookup(code)
          : await widget.onVerify(code, scanType);

      if (!mounted) return;

      await VisitorPassResultSheet.show(
        context,
        result: result,
        passCode: code,
        // A lookup can hand straight over to the real scan, so the desk does
        // not have to re-present the QR.
        onCheckIn: result.readOnly
            ? () => _followUp(code, VisitorScanType.checkIn)
            : null,
        onCheckOut: result.readOnly
            ? () => _followUp(code, VisitorScanType.checkOut)
            : null,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      // Only session, permission, network and server failures land here —
      // a refused pass is a result, not an exception.
      AdminFeedback.error(context, error.message);
      AdminLog.failure('Scan call failed: ${error.message}', error: error);
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminFeedback.error(context, 'Something went wrong. Please try again.');
      AdminLog.failure(
        'Scan call crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        _manual.clear();
        await _resumeCamera();
      }
    }
  }

  /// Runs the real scan after a read-only check, and replaces the sheet with
  /// the new result.
  Future<void> _followUp(String code, VisitorScanType type) async {
    final navigator = Navigator.of(context);

    try {
      final result = await widget.onVerify(code, type);
      if (!mounted) return;

      // Close the lookup's sheet before showing the scan's own.
      if (navigator.canPop()) navigator.pop();
      if (!mounted) return;

      await VisitorPassResultSheet.show(
        context,
        result: result,
        passCode: code,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      AdminFeedback.error(context, error.message);
    }
  }

  Future<void> _pauseCamera() async {
    try {
      await _controller?.pauseCamera();
    } catch (_) {
      // The controller may already be gone if the page is closing.
    }
  }

  Future<void> _resumeCamera() async {
    try {
      await _controller?.resumeCamera();
    } catch (_) {
      // Same: nothing to resume once the route has been popped.
    }
  }

  void _setMode(VisitorScanMode mode) {
    if (_mode == mode) return;
    AdminLog.ui('Scan mode → ${mode.name}');
    setState(() {
      _mode = mode;
      _lastCode = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        title: Text(
          'Scan visitor pass',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: tokens.textSecondary),
        actions: [
          if (_cameraAllowed)
            IconButton(
              onPressed: _toggleFlash,
              tooltip: _flashOn ? 'Turn torch off' : 'Turn torch on',
              icon: Icon(
                _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _flashOn ? tokens.warning : tokens.textSecondary,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _ModeSelector(mode: _mode, onChanged: _setMode),
            Expanded(child: _buildViewfinder(tokens)),
            _ManualEntry(
              controller: _manual,
              mode: _mode,
              busy: _processing,
              onSubmit: _submitManual,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder(AdminTokens tokens) {
    if (!_permissionChecked) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_cameraAllowed) {
      return _CameraUnavailable(
        supported: _cameraSupported,
        permanentlyDenied: _permanentlyDenied,
        onRetry: _requestCamera,
        onOpenSettings: openAppSettings,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: QRView(
            key: _qrKey,
            onQRViewCreated: _onQRViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: tokens.accent,
              borderRadius: AdminTokens.radiusMd,
              borderLength: 28,
              borderWidth: 8,
              cutOutSize: 250,
            ),
            onPermissionSet: (_, granted) {
              if (granted) return;
              // The plugin re-checks on its own; a refusal here means the
              // preview will stay black, so the fallback state is shown.
              AdminLog.failure('QRView reported permission refused');
              if (mounted) setState(() => _cameraAllowed = false);
            },
          ),
        ),
        if (_processing)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
        Positioned(
          left: AdminTokens.space5,
          right: AdminTokens.space5,
          bottom: AdminTokens.space5,
          child: _Hint(mode: _mode),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final VisitorScanMode mode;
  final ValueChanged<VisitorScanMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: tokens.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: VisitorScanMode.values.map((value) {
              final selected = value == mode;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space2),
                  child: InkWell(
                    onTap: () => onChanged(value),
                    borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                    child: AnimatedContainer(
                      duration: AdminTokens.fast,
                      padding: const EdgeInsets.symmetric(
                        vertical: AdminTokens.space3,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? tokens.accent : tokens.surfaceAlt,
                        borderRadius: BorderRadius.circular(
                          AdminTokens.radiusMd,
                        ),
                        border: Border.all(
                          color: selected ? tokens.accent : tokens.border,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            value.icon,
                            size: 18,
                            color: selected ? Colors.white : tokens.textMuted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : tokens.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AdminTokens.space3),
          Text(
            mode.isLookup
                ? 'Read-only. The pass keeps its current status.'
                : 'This scan changes the pass — ${mode.label.toLowerCase()} is '
                      'recorded against it.',
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.mode});

  final VisitorScanMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space4,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(mode.icon, size: 16, color: Colors.white),
          const SizedBox(width: AdminTokens.space3),
          const Expanded(
            child: Text(
              'Hold the visitor pass QR inside the frame',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.mode,
    required this.busy,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VisitorScanMode mode;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AdminTokens.space4,
        AdminTokens.space4,
        AdminTokens.space4,
        AdminTokens.space4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Or enter the pass code',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AdminTokens.space2),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  textInputAction: TextInputAction.go,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => onSubmit(),
                  style: TextStyle(
                    fontSize: 14,
                    letterSpacing: 1.2,
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. NS-4821',
                    prefixIcon: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              FilledButton(
                onPressed: busy ? null : onSubmit,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(mode.isLookup ? 'Check' : mode.label),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.supported,
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool supported;
  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final title = !supported
        ? 'Camera scanning is not available here'
        : (permanentlyDenied
              ? 'Camera access is blocked'
              : 'Camera access is needed to scan');

    final message = !supported
        ? 'This device has no scanner support. You can still check a pass by '
              'typing its code below.'
        : (permanentlyDenied
              ? 'Enable the camera for this app in system settings, then come '
                    'back. You can still type the pass code below.'
              : 'Allow the camera so the gate can read visitor QR codes. You '
                    'can also type the pass code below.');

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.warning.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.no_photography_outlined,
                    size: 30,
                    color: tokens.warning,
                  ),
                ),
                const SizedBox(height: AdminTokens.space5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AdminTokens.space2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (supported) ...[
                  const SizedBox(height: AdminTokens.space5),
                  Wrap(
                    spacing: AdminTokens.space3,
                    runSpacing: AdminTokens.space3,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
                      ),
                      if (permanentlyDenied)
                        OutlinedButton.icon(
                          onPressed: () => onOpenSettings(),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: const Text('Open settings'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
