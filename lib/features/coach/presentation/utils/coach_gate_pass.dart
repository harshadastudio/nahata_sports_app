import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/coach_log.dart';
import '../../domain/entities/coach_fee.dart';

/// Issuing a student's gate pass over WhatsApp.
///
/// The message is the website's `handleSendToWhatsApp` word for word, so a
/// student receiving one from a coach's phone gets exactly what the web
/// dashboard sends: the pass code, the enrollment details, and a link to the
/// QR image for the gate.
///
/// Nothing here throws. A pass that cannot be sent (no number on file, no
/// WhatsApp installed) is a message on the screen, not an exception the sheet
/// has to catch.
class CoachGatePass {
  const CoachGatePass._();

  /// What a coach sees on screen after trying to send.
  static const String noNumber = 'This student has no phone number on file.';
  static const String notApproved =
      'The gate pass opens once an admin approves this payment.';
  static const String failed = 'Could not open WhatsApp on this device.';
  static const String opening = 'Opening WhatsApp…';

  /// The WhatsApp body. Public so the sheet can preview it before sending.
  static String message(CoachFee fee) {
    final today = DateFormat('dd MMM yyyy').format(DateTime.now());
    final amount = NumberFormat.decimalPattern('en_IN').format(fee.amountPaid);
    final batch = fee.batchName.trim().isEmpty ? 'Batch' : fee.batchName.trim();

    return '🎓 *Hi ${fee.displayName}! Your Gate Pass — Nahata Sports Academy*\n'
        '\n'
        '📅 Date: $today\n'
        '🏃 Batch: $batch\n'
        '💰 Amount Paid: ₹$amount\n'
        '📆 Enrollment Date: ${fee.enrollmentDate ?? '—'}\n'
        '⏳ Valid Till: ${(fee.validTill ?? '').isEmpty ? 'No expiry' : fee.validTill}\n'
        '\n'
        '*Pass Code:* ${fee.gatePassCode}\n'
        '\n'
        '✅ *Status: APPROVED*\n'
        '\n'
        '🔐 Show this QR code at the entry gate:\n'
        '${fee.gatePassQrUrl}\n'
        '\n'
        '_Nahata Sports Complex_\n'
        '\n'
        'Thank you for choosing Nahata Sports Academy! 🏆';
  }

  /// Opens WhatsApp on the student's own chat with the pass filled in.
  ///
  /// Returns the line to show the coach — `null` on success is not used here
  /// because even the happy path has something worth saying.
  static Future<String> sendToWhatsApp(CoachFee fee) async {
    // Guarded rather than merely hidden: the gate scanner rejects a pass whose
    // record is not approved, so sending one early would have the student
    // turned away at the gate holding a QR the coach gave them.
    if (!fee.isApproved) return notApproved;
    if (!fee.canWhatsApp) return noNumber;

    final uri = Uri.parse(
      'https://wa.me/${fee.whatsappNumber}'
      '?text=${Uri.encodeComponent(message(fee))}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        CoachLog.success('Opened WhatsApp for gate pass ${fee.gatePassCode}');
        return opening;
      }
    } catch (error) {
      CoachLog.failure('WhatsApp could not be opened', error: error);
    }

    return failed;
  }
}
