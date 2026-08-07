import 'package:flutter/services.dart';

import '../../../admin/core/admin_log.dart';
import '../../domain/entities/gate_scan.dart';

/// The sound and vibration a guard feels rather than reads.
///
/// A gate is noisy, the phone is at arm's length and the guard is looking at
/// the person, not the screen — so the verdict has to arrive through the hand
/// before it arrives through the eyes. Three distinct patterns, so success,
/// "wait a moment" and refusal are told apart without looking:
///
///  * granted — one light tap and a click,
///  * soft refusal — a medium tap,
///  * invalid — a heavy double tap and an alert tone.
///
/// Built on `HapticFeedback` and `SystemSound` from `flutter/services`, which
/// need no plugin and degrade to nothing on a device without a vibrator. Every
/// call is fire-and-forget: feedback must never delay or fail a scan.
class GateFeedback {
  const GateFeedback._();

  /// Plays the pattern for [outcome]. Never throws, never awaits anything the
  /// caller has to care about.
  static Future<void> forOutcome(GateScanOutcome outcome) async {
    try {
      switch (outcome.severity) {
        case GateScanSeverity.success:
          await HapticFeedback.lightImpact();
          await SystemSound.play(SystemSoundType.click);
        case GateScanSeverity.warning:
          await HapticFeedback.mediumImpact();
        case GateScanSeverity.danger:
          await HapticFeedback.heavyImpact();
          await SystemSound.play(SystemSoundType.alert);
          // The second tap is what makes a refusal unmistakable.
          await Future<void>.delayed(const Duration(milliseconds: 140));
          await HapticFeedback.heavyImpact();
      }
    } catch (error) {
      AdminLog.failure('Scan feedback unavailable', error: error);
    }
  }

  /// The tap that confirms a code was read, before the call goes out.
  static Future<void> captured() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {
      // A device with no haptics is not a problem worth reporting twice.
    }
  }
}