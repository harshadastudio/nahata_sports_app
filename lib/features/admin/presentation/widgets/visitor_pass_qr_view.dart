import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/config/api_config.dart';
import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';

/// Where a pass's QR image comes from.
///
/// The backend field is documented only as "QR Code", and a field like that
/// carries one of four things depending on how the pass was generated: an
/// absolute image URL, a `data:` URI, a stored path, or the encoded payload
/// itself. This resolves whichever it is, and falls back to generating the QR
/// from the pass code — which is exactly what `/verify` and `/lookup` expect
/// to receive back.
@immutable
class VisitorPassQrSource {
  const VisitorPassQrSource._({this.imageUrl, this.imageBytes, this.payload});

  /// A remote image to display.
  final String? imageUrl;

  /// An inline image, decoded from a `data:` URI.
  final Uint8List? imageBytes;

  /// Text to encode locally when there is no image to show.
  final String? payload;

  bool get isEmpty => imageUrl == null && imageBytes == null && payload == null;

  static const List<String> _imageExtensions = [
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
  ];

  factory VisitorPassQrSource.of(VisitorPass pass) {
    final raw = (pass.qrCode ?? '').trim();
    final code = (pass.passCode ?? '').trim();

    if (raw.isEmpty) {
      return VisitorPassQrSource._(payload: code.isEmpty ? null : code);
    }

    if (raw.startsWith('data:image')) {
      final bytes = _decodeDataUri(raw);
      if (bytes != null) return VisitorPassQrSource._(imageBytes: bytes);
    }

    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      // A URL that points at an image is displayed; a URL that *is* the payload
      // (a check-in link) is encoded instead, so the QR still scans.
      if (_looksLikeImage(raw)) {
        return VisitorPassQrSource._(imageUrl: raw);
      }
      return VisitorPassQrSource._(payload: raw);
    }

    // A stored path such as `uploads/qr/NS-4821.png`, served by the web host.
    if (_looksLikeImage(raw) && raw.contains('/')) {
      final path = raw.startsWith('/') ? raw.substring(1) : raw;
      return VisitorPassQrSource._(
        imageUrl: '${ApiConfig.attendanceBaseUrl}/$path',
      );
    }

    return VisitorPassQrSource._(payload: raw);
  }

  /// The QR as PNG bytes, for saving or attaching to a share.
  ///
  /// Returns null for a remote image — those are shared as a link instead of
  /// being downloaded and re-uploaded.
  Future<Uint8List?> pngBytes({double size = 640}) async {
    final inline = imageBytes;
    if (inline != null) return inline;

    final data = payload;
    if (data == null || data.isEmpty) return null;

    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF000000),
      ),
    );

    final bytes = await painter.toImageData(
      size,
      format: ui.ImageByteFormat.png,
    );
    return bytes?.buffer.asUint8List();
  }

  static bool _looksLikeImage(String value) {
    final withoutQuery = value.split('?').first.toLowerCase();
    return _imageExtensions.any(withoutQuery.endsWith);
  }

  static Uint8List? _decodeDataUri(String value) {
    final separator = value.indexOf(',');
    if (separator < 0) return null;
    try {
      return base64Decode(value.substring(separator + 1).trim());
    } catch (_) {
      // A malformed data URI is treated as "no image", never as a crash.
      return null;
    }
  }
}

/// The pass's QR code, on the white plate a scanner needs.
///
/// The plate is always white regardless of the console's theme: a QR rendered
/// on a dark surface will not scan.
class VisitorPassQrView extends StatelessWidget {
  const VisitorPassQrView({
    super.key,
    required this.pass,
    this.size = 200,
    this.showCode = true,
  });

  final VisitorPass pass;
  final double size;

  /// Whether the pass code is printed under the QR.
  final bool showCode;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final source = VisitorPassQrSource.of(pass);
    final code = (pass.passCode ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AdminTokens.space3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(color: tokens.border),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: _QrContent(source: source, size: size),
          ),
        ),
        if (showCode && code.isNotEmpty) ...[
          const SizedBox(height: AdminTokens.space3),
          Text(
            code,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

class _QrContent extends StatelessWidget {
  const _QrContent({required this.source, required this.size});

  final VisitorPassQrSource source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = source.imageBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const _QrUnavailable(),
      );
    }

    final url = source.imageUrl;
    if (url != null) {
      return CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => const _QrUnavailable(),
      );
    }

    final payload = source.payload;
    if (payload == null || payload.isEmpty) return const _QrUnavailable();

    return QrImageView(
      data: payload,
      version: QrVersions.auto,
      size: size,
      gapless: true,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Color(0xFF000000),
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Color(0xFF000000),
      ),
      errorStateBuilder: (_, __) => const _QrUnavailable(),
    );
  }
}

class _QrUnavailable extends StatelessWidget {
  const _QrUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_rounded, size: 34, color: Color(0xFF94A3B8)),
          SizedBox(height: AdminTokens.space2),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AdminTokens.space3),
            child: Text(
              'QR not available',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
