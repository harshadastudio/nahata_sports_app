import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_dialogs.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../domain/entities/gate_scan.dart';
import '../../domain/entities/pass_code_router.dart';
import '../widgets/gate_feedback.dart';
import '../widgets/gate_scan_result_sheet.dart';

/// Runs one scan and reports the verdict.
typedef GateScanHandler = Future<GateScanResult> Function(
  String passCode,
  GateDirection direction,
);

/// The gate scanner, shared by all four modules.
///
/// One camera implementation, not four: the modules differ only in which
/// endpoint a code goes to, which is [onScan]. Everything a guard needs at a
/// door is here and behaves identically whichever gate they are on —
///
///  * camera scanning with a torch, a front/back flip and continuous mode,
///  * manual entry and paste for an unreadable QR or a camera-less desk,
///  * IN / OUT selection, where the gate has directions,
///  * sound, vibration and colour on every verdict ([GateFeedback]),
///  * a result sheet that never crashes, whatever came back.
///
/// **Continuous mode** keeps the camera live after each verdict and re-arms
/// automatically, for a queue. It is off by default: at a normal gate the
/// guard wants to read the result before the next person steps up.
class GateScannerPage extends StatefulWidget {
  const GateScannerPage({
    super.key,
    required this.kind,
    required this.onScan,
    this.initialDirection = GateDirection.inbound,
    this.supportsDirection = true,
    this.onRecorded,
    this.title,
    this.initialCode,
  });

  final GateScanKind kind;

  /// Where a code goes. The module supplies it, so this page knows nothing
  /// about endpoints.
  final GateScanHandler onScan;

  final GateDirection initialDirection;

  /// False for the coaching gate, where a scan marks attendance and there is no
  /// in/out to choose.
  final bool supportsDirection;

  /// Called after every scan, successful or not — the dashboard uses it to
  /// record the journal entry and refresh its counters.
  final void Function(GateScanResult result)? onRecorded;

  final String? title;

  /// Pre-fills the manual field — the global search hands the code it resolved
  /// straight over, so the guard does not retype what they just pasted. It is
  /// **not** submitted automatically: the guard chooses the direction first.
  final String? initialCode;

  /// Pushes the scanner, carrying the console's theme onto the new route — a
  /// pushed page builds outside the dashboard's own [Theme], so without this it
  /// would render in the customer app's colours.
  static Future<void> push(
    BuildContext context, {
    required GateScanKind kind,
    required GateScanHandler onScan,
    GateDirection initialDirection = GateDirection.inbound,
    bool supportsDirection = true,
    void Function(GateScanResult result)? onRecorded,
    String? title,
    String? initialCode,
  }) {
    final theme = Theme.of(context);

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: theme,
          child: GateScannerPage(
            kind: kind,
            onScan: onScan,
            initialDirection: initialDirection,
            supportsDirection: supportsDirection,
            onRecorded: onRecorded,
            title: title,
            initialCode: initialCode,
          ),
        ),
      ),
    );
  }

  @override
  State<GateScannerPage> createState() => _GateScannerPageState();
}

class _GateScannerPageState extends State<GateScannerPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'GateScannerQR');
  final TextEditingController _manual = TextEditingController();

  QRViewController? _controller;

  late GateDirection _direction = widget.initialDirection;

  bool _cameraAllowed = false;
  bool _permissionChecked = false;
  bool _permanentlyDenied = false;
  bool _flashOn = false;
  bool _continuous = false;

  /// True from the moment a code is accepted until its verdict has been dealt
  /// with. Without it the camera stream fires the same code many times a second
  /// and every one of them would hit the scan endpoint.
  bool _processing = false;

  /// The last code submitted, so a QR left in front of the lens is not
  /// re-submitted the instant the sheet closes.
  String? _lastCode;

  @override
  void initState() {
    super.initState();
    AdminLog.life('GateScannerPage mounted (${widget.kind.name})');
    final prefilled = (widget.initialCode ?? '').trim();
    if (prefilled.isNotEmpty) _manual.text = prefilled;
    _requestCamera();
  }

  /// The camera preview is a native view: on Android it has to be paused across
  /// a hot reload and on iOS resumed, or it comes back black.
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
    // The QRViewController disposes itself when the QRView unmounts — calling
    // it here as well is deprecated and would double-dispose the native view.
    _manual.dispose();
    AdminLog.life('GateScannerPage disposed');
    super.dispose();
  }

  bool get _cameraSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
    AdminLog.state('Gate QR view created');

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

  Future<void> _flipCamera() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.flipCamera();
      AdminLog.ui('Camera flipped');
    } catch (error) {
      AdminLog.failure('This device has only one camera', error: error);
      if (!mounted) return;
      AdminFeedback.info(context, 'This device has only one camera.');
    }
  }

  Future<void> _pasteCode() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.isEmpty) {
        if (!mounted) return;
        AdminFeedback.info(context, 'The clipboard is empty.');
        return;
      }

      final code = PassCodeRouter.extract(text) ?? text;
      _manual.text = code;
      if (!mounted) return;
      AdminFeedback.info(context, 'Pasted $code');
    } catch (error) {
      AdminLog.failure('Clipboard unavailable', error: error);
    }
  }

  Future<void> _handleScanned(String raw) async {
    final code = PassCodeRouter.extract(raw);

    if (code == null) {
      AdminLog.failure(
        'Unreadable QR: ${raw.length > 120 ? '${raw.substring(0, 120)}…' : raw}',
      );
      await _pauseCamera();
      if (!mounted) return;

      // A malformed QR is a refusal like any other: the guard is told, the
      // phone buzzes, and the camera comes back. It never reaches the network.
      unawaited(GateFeedback.forOutcome(GateScanOutcome.invalid));
      AdminFeedback.error(
        context,
        'That QR code is not a ${widget.kind.label.toLowerCase()}. '
        'Try again, or type the code.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      await _resumeCamera();
      return;
    }

    if (code == _lastCode && _processing) return;

    await _submit(code, fromCamera: true);
  }

  Future<void> _submitManual() async {
    final code = PassCodeRouter.extract(_manual.text) ?? _manual.text.trim();
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
      // The confirmation that a code was read, before the round trip.
      unawaited(GateFeedback.captured());
    }

    // The repository turns every ending into a result, so there is nothing to
    // catch here — but a crash in the handler itself still must not take the
    // gate down.
    GateScanResult result;
    try {
      result = await widget.onScan(code, _direction);
    } catch (error, stackTrace) {
      AdminLog.failure(
        'Gate scan handler crashed',
        error: error,
        stackTrace: stackTrace,
      );
      result = GateScanResult.failure(
        kind: widget.kind,
        passCode: code,
        direction: _direction,
        message: 'Something went wrong. Please try again.',
      );
    }

    widget.onRecorded?.call(result);
    unawaited(GateFeedback.forOutcome(result.outcome));

    if (!mounted) return;

    if (_continuous && result.isSuccess) {
      // A queue: the verdict flashes past as a snackbar and the camera stays
      // live. Only successes are passed over — anything else needs reading.
      AdminFeedback.success(
        context,
        '${result.headline} · ${result.displayName}',
      );
    } else {
      await GateScanResultSheet.show(context, result: result);
    }

    if (!mounted) return;
    setState(() => _processing = false);
    _manual.clear();
    await _resumeCamera();
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

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        title: Text(
          widget.title ?? '${widget.kind.label} Scanner',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: tokens.textSecondary),
        actions: [
          if (_cameraAllowed) ...[
            IconButton(
              onPressed: _toggleFlash,
              tooltip: _flashOn ? 'Torch off' : 'Torch on',
              color: _flashOn ? tokens.warning : tokens.textSecondary,
              icon: Icon(
                _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
            ),
            IconButton(
              onPressed: _flipCamera,
              tooltip: 'Switch camera',
              color: tokens.textSecondary,
              icon: const Icon(Icons.cameraswitch_rounded),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: narrow
            ? ListView(
                padding: const EdgeInsets.all(AdminTokens.space4),
                children: _sections(context),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(AdminTokens.space6),
                    children: _sections(context),
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _sections(BuildContext context) {
    return [
      if (widget.supportsDirection) ...[
        _DirectionToggle(
          direction: _direction,
          onChanged: (next) => setState(() => _direction = next),
        ),
        const SizedBox(height: AdminTokens.space4),
      ],
      _CameraPanel(
        qrKey: _qrKey,
        allowed: _cameraAllowed,
        checked: _permissionChecked,
        permanentlyDenied: _permanentlyDenied,
        supported: _cameraSupported,
        processing: _processing,
        onCreated: _onQRViewCreated,
        onRetryPermission: _requestCamera,
      ),
      const SizedBox(height: AdminTokens.space4),
      _ContinuousToggle(
        value: _continuous,
        onChanged: (next) => setState(() => _continuous = next),
      ),
      const SizedBox(height: AdminTokens.space4),
      _ManualEntry(
        controller: _manual,
        busy: _processing,
        onSubmit: _submitManual,
        onPaste: _pasteCode,
      ),
    ];
  }
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _DirectionToggle extends StatelessWidget {
  const _DirectionToggle({required this.direction, required this.onChanged});

  final GateDirection direction;
  final ValueChanged<GateDirection> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space2),
      child: Row(
        children: [
          for (final option in GateDirection.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(option),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: AdminTokens.fast,
                  curve: AdminTokens.curve,
                  padding: const EdgeInsets.symmetric(
                    vertical: AdminTokens.space3,
                  ),
                  decoration: BoxDecoration(
                    color: direction == option
                        ? (option == GateDirection.inbound
                              ? tokens.success.withValues(alpha: 0.14)
                              : tokens.warning.withValues(alpha: 0.14))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option == GateDirection.inbound
                            ? Icons.login_rounded
                            : Icons.logout_rounded,
                        size: 18,
                        color: direction == option
                            ? (option == GateDirection.inbound
                                  ? tokens.success
                                  : tokens.warning)
                            : tokens.textMuted,
                      ),
                      const SizedBox(width: AdminTokens.space2),
                      Text(
                        option.label,
                        style: TextStyle(
                          color: direction == option
                              ? tokens.textPrimary
                              : tokens.textMuted,
                          fontSize: 13.5,
                          fontWeight: direction == option
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CameraPanel extends StatelessWidget {
  const _CameraPanel({
    required this.qrKey,
    required this.allowed,
    required this.checked,
    required this.permanentlyDenied,
    required this.supported,
    required this.processing,
    required this.onCreated,
    required this.onRetryPermission,
  });

  final GlobalKey qrKey;
  final bool allowed;
  final bool checked;
  final bool permanentlyDenied;
  final bool supported;
  final bool processing;
  final void Function(QRViewController controller) onCreated;
  final VoidCallback onRetryPermission;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
      child: AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: Colors.black,
          child: !checked
              ? const Center(child: CircularProgressIndicator())
              : allowed
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          QRView(
                            key: qrKey,
                            onQRViewCreated: onCreated,
                            overlay: QrScannerOverlayShape(
                              borderColor: tokens.accent,
                              borderRadius: AdminTokens.radiusMd,
                              borderLength: 32,
                              borderWidth: 8,
                              cutOutSize:
                                  MediaQuery.sizeOf(context).width * 0.62,
                            ),
                          ),
                          if (processing)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.55),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      )
                    : _CameraUnavailable(
                        supported: supported,
                        permanentlyDenied: permanentlyDenied,
                        onRetry: onRetryPermission,
                      ),
        ),
      ),
    );
  }
}

class _CameraUnavailable extends StatelessWidget {
  const _CameraUnavailable({
    required this.supported,
    required this.permanentlyDenied,
    required this.onRetry,
  });

  final bool supported;
  final bool permanentlyDenied;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_rounded,
              size: 40,
              color: Colors.white70,
            ),
            const SizedBox(height: AdminTokens.space4),
            Text(
              supported
                  ? (permanentlyDenied
                        ? 'Camera access is blocked'
                        : 'Camera access is needed to scan')
                  : 'This device has no scanner camera',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AdminTokens.space2),
            const Text(
              'You can still type or paste the pass code below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            if (supported) ...[
              const SizedBox(height: AdminTokens.space4),
              FilledButton.icon(
                onPressed: permanentlyDenied ? openAppSettings : onRetry,
                icon: const Icon(Icons.settings_rounded, size: 18),
                label: Text(
                  permanentlyDenied ? 'Open settings' : 'Allow camera',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContinuousToggle extends StatelessWidget {
  const _ContinuousToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space4,
        vertical: AdminTokens.space2,
      ),
      child: Row(
        children: [
          Icon(Icons.repeat_rounded, size: 18, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Continuous scanning',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Keep the camera live for a queue. Refusals still stop.',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ManualEntry extends StatelessWidget {
  const _ManualEntry({
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onPaste,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the code by hand',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'For an unreadable QR, or a desk with no camera.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminTokens.space4),
          TextField(
            controller: controller,
            enabled: !busy,
            autofocus: false,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 15,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. EVTPASS-2026-0003312',
              prefixIcon: Icon(
                Icons.keyboard_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
              suffixIcon: IconButton(
                onPressed: busy ? null : onPaste,
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                tooltip: 'Paste',
                color: tokens.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AdminTokens.space3),
          FilledButton.icon(
            onPressed: busy ? null : onSubmit,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(busy ? 'Checking…' : 'Verify code'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ],
      ),
    );
  }
}