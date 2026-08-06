import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../widgets/visitor_pass_qr_view.dart';

/// The outcome of a share action, so the caller can say what happened without
/// having to know which channel was used.
class ShareOutcome {
  const ShareOutcome({required this.ok, required this.message});

  const ShareOutcome.ok(String message) : this(ok: true, message: message);

  const ShareOutcome.failed(String message) : this(ok: false, message: message);

  final bool ok;
  final String message;
}

/// Sharing a visitor pass: the system sheet, WhatsApp, the clipboard, and
/// saving the QR to the device gallery.
///
/// Every entry point returns a [ShareOutcome] rather than throwing — a share
/// that cannot happen (no WhatsApp installed, gallery permission refused) is a
/// message at the desk, not an error the page has to catch.
class VisitorPassSharing {
  const VisitorPassSharing._();

  /// The system share sheet, with the QR attached when one can be produced.
  static Future<ShareOutcome> share(VisitorPass pass) async {
    final text = pass.shareText(qrLink: _remoteQrLink(pass));

    try {
      final file = await _writeQrToTemp(pass);

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'Visitor Pass — ${pass.displayName}',
          files: file == null ? null : [XFile(file.path)],
        ),
      );

      AdminLog.success('Shared visitor pass ${pass.reference}');
      return const ShareOutcome.ok('Visitor pass shared.');
    } catch (error, stackTrace) {
      AdminLog.failure(
        'Sharing the visitor pass failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const ShareOutcome.failed('Could not open the share sheet.');
    }
  }

  /// Opens WhatsApp on the visitor's own number when it is a valid 10-digit
  /// mobile, and otherwise lets them pick the chat.
  static Future<ShareOutcome> shareToWhatsApp(VisitorPass pass) async {
    final text = pass.shareText(qrLink: _remoteQrLink(pass));
    final digits = (pass.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');

    // wa.me needs the country code; the module's numbers are Indian 10-digit
    // mobiles, so 91 is prepended when the number is exactly that.
    final target = digits.length == 10
        ? '91$digits'
        : (digits.length > 10 ? digits : '');

    final uri = Uri.parse(
      'https://wa.me/$target?text=${Uri.encodeComponent(text)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        AdminLog.success('Opened WhatsApp for ${pass.reference}');
        return const ShareOutcome.ok('Opening WhatsApp…');
      }
    } catch (error) {
      AdminLog.failure('WhatsApp could not be opened', error: error);
    }

    // No WhatsApp on the device — the pass still gets shared, just elsewhere.
    AdminLog.ui('WhatsApp unavailable — falling back to the share sheet');
    return share(pass);
  }

  static Future<ShareOutcome> copyCode(VisitorPass pass) async {
    final code = (pass.passCode ?? '').trim();
    if (code.isEmpty) {
      return const ShareOutcome.failed('This pass has no code to copy.');
    }

    await Clipboard.setData(ClipboardData(text: code));
    AdminLog.ui('Copied pass code $code');
    return ShareOutcome.ok('Pass code $code copied.');
  }

  /// Saves the QR to the device gallery.
  ///
  /// Android 13+ needs no permission to *write* an image through MediaStore,
  /// and older versions do; the request is therefore made but a refusal on a
  /// version that does not need it is not treated as fatal.
  static Future<ShareOutcome> downloadQr(VisitorPass pass) async {
    final bytes = await VisitorPassQrSource.of(pass).pngBytes();
    if (bytes == null) {
      return const ShareOutcome.failed(
        'This pass has no QR image that can be saved.',
      );
    }

    try {
      if (Platform.isIOS) {
        final status = await Permission.photosAddOnly.request();
        if (!status.isGranted && !status.isLimited) {
          return const ShareOutcome.failed(
            'Allow photo access to save the QR code.',
          );
        }
      } else if (Platform.isAndroid) {
        // Ignored on Android 13+, where the plugin writes through MediaStore.
        await Permission.storage.request();
      }

      final name =
          'visitor_pass_${(pass.passCode ?? pass.reference).replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '')}';

      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: name,
      );

      final saved = result is Map && (result['isSuccess'] == true);
      if (!saved) {
        AdminLog.failure('Gallery save reported failure: $result');
        return const ShareOutcome.failed('Could not save the QR code.');
      }

      AdminLog.success('Saved QR for ${pass.reference} to the gallery');
      return const ShareOutcome.ok('QR code saved to your gallery.');
    } catch (error, stackTrace) {
      AdminLog.failure(
        'Saving the QR failed',
        error: error,
        stackTrace: stackTrace,
      );
      return const ShareOutcome.failed('Could not save the QR code.');
    }
  }

  /// Writes the QR into the cache directory so it can ride along with a share.
  /// Returns null when there is nothing to write — the text still goes out.
  static Future<File?> _writeQrToTemp(VisitorPass pass) async {
    try {
      final bytes = await VisitorPassQrSource.of(pass).pngBytes();
      if (bytes == null) return null;

      final directory = await getTemporaryDirectory();
      final safeCode = (pass.passCode ?? pass.reference).replaceAll(
        RegExp(r'[^A-Za-z0-9_\-]'),
        '',
      );
      final file = File('${directory.path}/visitor_pass_$safeCode.png');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (error) {
      AdminLog.failure('Could not write the QR to share', error: error);
      return null;
    }
  }

  /// The QR link worth putting in the message body — only a real URL, never a
  /// `data:` blob or a locally generated payload.
  static String? _remoteQrLink(VisitorPass pass) {
    final url = VisitorPassQrSource.of(pass).imageUrl;
    if (url == null || url.isEmpty) return null;
    return url;
  }
}
