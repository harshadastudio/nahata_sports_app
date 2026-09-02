import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_pass_scan.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../theme/coach_theme.dart';

/// The Student Pass Scanner.
///
/// ⚠️ Scanning is **not** a lookup. `POST /fees/scan-pass` marks the student
/// `Present` for today whenever the caller is a coach, so this screen is built
/// around never firing the same code twice: the camera stream is gated on
/// [_processing], the last code is remembered, and the result sheet has to be
/// dismissed before the next scan is accepted.
class CoachScannerPage extends StatefulWidget {
  const CoachScannerPage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachScannerPage> createState() => _CoachScannerPageState();
}

class _CoachScannerPageState extends State<CoachScannerPage>
    with WidgetsBindingObserver {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'CoachGatePassQR');
  final TextEditingController _manual = TextEditingController();

  late final CoachDashboardRepository _repository =
      widget.repository ?? CoachDashboardRepositoryImpl();

  QRViewController? _controller;

  bool _cameraAllowed = false;
  bool _permissionChecked = false;
  bool _permanentlyDenied = false;
  bool _flashOn = false;

  /// True from the moment a code is accepted until its result has been dealt
  /// with. Without it the camera stream would fire the same code many times a
  /// second, and every one of them would mark attendance again.
  bool _processing = false;

  /// The last code sent, so a pass left in front of the lens is not
  /// re-submitted the instant the result sheet closes.
  String? _lastCode;

  /// Scans made in this session, newest first — so a coach at the gate can see
  /// who has already come through without leaving the screen.
  final List<CoachPassScan> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CoachLog.life('CoachScannerPage mounted');
    _requestCamera();
  }

  /// The camera preview is a native view: on Android it has to be paused
  /// across a hot reload and on iOS resumed, or it comes back black.
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
    // QRViewController disposes itself when the QRView unmounts; disposing it
    // here as well would double-dispose the native view.
    _manual.dispose();
    CoachLog.life('CoachScannerPage disposed');
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

    CoachLog.state('Camera permission → $status');
    setState(() {
      _permissionChecked = true;
      _cameraAllowed = status.isGranted || status.isLimited;
      _permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
    });
  }

  void _onQRViewCreated(QRViewController controller) {
    _controller = controller;
    CoachLog.state('QR view created');

    controller.scannedDataStream.listen((scanData) {
      final raw = scanData.code;
      if (raw == null || raw.trim().isEmpty) return;
      if (_processing) return;
      _submit(raw);
    });
  }

  Future<void> _pauseCamera() async {
    try {
      await _controller?.pauseCamera();
    } catch (e) {
      CoachLog.failure('Could not pause the camera', error: e);
    }
  }

  Future<void> _resumeCamera() async {
    try {
      await _controller?.resumeCamera();
    } catch (e) {
      CoachLog.failure('Could not resume the camera', error: e);
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      await controller.toggleFlash();
      final status = await controller.getFlashStatus();
      if (!mounted) return;
      setState(() => _flashOn = status ?? !_flashOn);
    } catch (e) {
      // Not every device exposes a torch; failing to toggle must not take the
      // scanner down.
      CoachLog.failure('Torch unavailable', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// A pass code carries the enrollment id in its trailing digits. Anything
  /// without them cannot be a pass, and is rejected here rather than sent —
  /// the backend would answer 400, but only after a round trip.
  static bool _looksLikePass(String raw) =>
      RegExp(r'\d+\s*$').hasMatch(raw.trim());

  Future<void> _submit(String raw) async {
    final code = raw.trim();

    // The same pass still in front of the lens — ignored silently, because
    // re-sending it would re-hit an attendance-marking endpoint.
    if (code == _lastCode) return;

    if (!_looksLikePass(code)) {
      CoachLog.failure(
        'Unreadable pass QR: '
        '${code.length > 100 ? '${code.substring(0, 100)}…' : code}',
      );
      _processing = true;
      await _pauseCamera();
      if (!mounted) return;

      _toast('That is not a student gate pass.', CoachTokens.danger);
      await Future<void>.delayed(const Duration(milliseconds: 900));
      _processing = false;
      await _resumeCamera();
      return;
    }

    setState(() => _processing = true);
    _lastCode = code;
    await _pauseCamera();

    try {
      final scan = await _repository.scanStudentPass(code);
      if (!mounted) return;

      setState(() => _history.insert(0, scan));
      await _showResult(scan);
    } on ApiException catch (e) {
      if (!mounted) return;
      await _showFailure(e.message);
    } catch (e) {
      CoachLog.failure('Pass scan failed', error: e);
      if (!mounted) return;
      await _showFailure('Could not check that pass. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _processing = false);
        // Cleared only now, so the next scan of a *different* pass is accepted
        // while a repeat of this one still is not — until the coach moves the
        // camera away and back.
        await _resumeCamera();
      }
    }
  }

  Future<void> _submitManual() async {
    final code = _manual.text.trim();
    if (code.isEmpty) return;

    _manual.clear();
    FocusScope.of(context).unfocus();
    // Typed entry is deliberate, so the repeat guard must not swallow it.
    _lastCode = null;
    await _submit(code);
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _showFailure(String message) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultSheet(
        tone: CoachTokens.danger,
        icon: Icons.gpp_bad_outlined,
        title: 'Pass not accepted',
        message: message,
      ),
    );
  }

  Future<void> _showResult(CoachPassScan scan) async {
    final tone = switch (scan.outcome) {
      CoachScanOutcome.marked ||
      CoachScanOutcome.updated => CoachTokens.success,
      CoachScanOutcome.already => CoachTokens.warning,
      _ => CoachTokens.info,
    };

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ResultSheet(
        tone: tone,
        icon: scan.didMark
            ? Icons.verified_rounded
            : Icons.check_circle_outline_rounded,
        title: scan.displayName,
        // The backend already phrases this for display, so its sentence is
        // shown rather than one composed here.
        message: scan.message ?? 'Pass verified.',
        scan: scan,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Student Pass Scanner',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_cameraAllowed)
            IconButton(
              tooltip: _flashOn ? 'Torch off' : 'Torch on',
              onPressed: _toggleFlash,
              icon: Icon(
                _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _scannerPane(),
          _manualEntry(),
          Expanded(child: _historyList()),
        ],
      ),
    );
  }

  Widget _scannerPane() {
    return SizedBox(
      height: 300,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraAllowed)
            QRView(
              key: _qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: Colors.white,
                borderRadius: 14,
                borderLength: 28,
                borderWidth: 8,
                cutOutSize: 210,
              ),
            )
          else
            _permissionPane(),
          if (_processing)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: CoachTokens.space3),
                  Text(
                    'Checking pass…',
                    style: TextStyle(color: Colors.white, fontSize: 13.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _permissionPane() {
    if (!_permissionChecked) {
      return const ColoredBox(
        color: Colors.black87,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final unsupported = !_cameraSupported;

    return ColoredBox(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(CoachTokens.space6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              unsupported
                  ? Icons.no_photography_outlined
                  : Icons.videocam_off_outlined,
              size: 34,
              color: Colors.white70,
            ),
            const SizedBox(height: CoachTokens.space3),
            Text(
              unsupported ? 'No camera on this device' : 'Camera access is off',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: CoachTokens.space2),
            Text(
              unsupported
                  ? 'Type the pass code below instead.'
                  : 'Allow the camera to scan passes, or type the code below.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            if (!unsupported) ...[
              const SizedBox(height: CoachTokens.space4),
              FilledButton(
                onPressed: _permanentlyDenied
                    ? openAppSettings
                    : _requestCamera,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: CoachTokens.brand,
                ),
                child: Text(
                  _permanentlyDenied ? 'Open settings' : 'Allow camera',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _manualEntry() {
    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.all(CoachTokens.space4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manual,
              enabled: !_processing,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _submitManual(),
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'GATEPASS-2026-000042',
                hintStyle: const TextStyle(
                  fontSize: 13.5,
                  color: CoachTokens.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.confirmation_number_outlined,
                  size: 19,
                  color: CoachTokens.textMuted,
                ),
                filled: true,
                fillColor: CoachTokens.canvas,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: CoachTokens.space3,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  borderSide: const BorderSide(color: CoachTokens.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  borderSide: const BorderSide(color: CoachTokens.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  borderSide: const BorderSide(
                    color: CoachTokens.brand,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: CoachTokens.space3),
          FilledButton(
            onPressed: _processing ? null : _submitManual,
            style: FilledButton.styleFrom(
              backgroundColor: CoachTokens.brand,
              minimumSize: const Size(52, 46),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
              ),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _historyList() {
    if (_history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(CoachTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                size: 30,
                color: CoachTokens.textMuted,
              ),
              SizedBox(height: CoachTokens.space3),
              Text(
                'Scanning a pass marks that student\npresent for today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: CoachTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        CoachTokens.space6,
      ),
      itemCount: _history.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: CoachTokens.space3),
            child: Text(
              'Scanned this session (${_history.length})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CoachTokens.textMuted,
              ),
            ),
          );
        }

        final scan = _history[index - 1];
        final tone = scan.didMark ? CoachTokens.success : CoachTokens.warning;

        return CoachCard(
          margin: const EdgeInsets.only(bottom: CoachTokens.space2 + 2),
          padding: const EdgeInsets.symmetric(
            horizontal: CoachTokens.space3 + 2,
            vertical: CoachTokens.space3,
          ),
          accentColor: tone,
          child: Row(
            children: [
              CoachAvatar(
                initial: scan.initial,
                imageUrl: scan.avatar,
                radius: 17,
                color: tone,
              ),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scan.displayName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if (scan.batchName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        scan.batchName,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: CoachTokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if ((scan.checkInTime ?? '').isNotEmpty)
                Text(
                  scan.checkInTime!.substring(0, 5),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: tone,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The sheet shown after every scan, successful or not.
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.scan,
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String message;
  final CoachPassScan? scan;

  @override
  Widget build(BuildContext context) {
    final details = scan;

    return Container(
      decoration: const BoxDecoration(
        color: CoachTokens.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CoachTokens.radiusLg + 4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space5,
        CoachTokens.space5,
        CoachTokens.space5,
        CoachTokens.space6,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(CoachTokens.space4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: tone),
            ),
            const SizedBox(height: CoachTokens.space4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: CoachTokens.textDark,
              ),
            ),
            const SizedBox(height: CoachTokens.space2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: CoachTokens.textBody,
              ),
            ),
            if (details != null) ...[
              const SizedBox(height: CoachTokens.space5),
              Container(
                padding: const EdgeInsets.all(CoachTokens.space4),
                decoration: BoxDecoration(
                  color: CoachTokens.canvas,
                  borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
                ),
                child: Column(
                  children: [
                    _row('Batch', details.batchName),
                    _row('Sport', details.sportName),
                    _row('Schedule', details.scheduleLabel),
                    _row('Phone', details.studentPhone),
                    _row('Blood group', details.bloodGroup),
                    _row('Check-in', details.checkInTime ?? ''),
                    _row('Pass', details.passCode),
                  ],
                ),
              ),
            ],
            const SizedBox(height: CoachTokens.space5),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: CoachTokens.brand,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  ),
                ),
                child: const Text('Scan next'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space2 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: CoachTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CoachTokens.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
