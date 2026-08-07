/// The result of scanning a student gate pass.
///
/// From `POST /fees/scan-pass`, which takes `{passCode}`.
///
/// ⚠️ **This call has a side effect when the caller is a COACH**: the backend
/// marks the student `Present` for today and writes a scan-log row. It is not a
/// lookup — never call it to preview a pass, and never retry it blindly.
///
/// The pass code is `GATEPASS-YYYY-000042`, whose trailing number is the
/// `StudentBatches` (enrollment) id. The backend parses the trailing digits, so
/// a bare id or a code with surrounding noise from a QR reader is accepted too.
library;

/// What the scan did to today's attendance.
enum CoachScanOutcome {
  /// No record existed — the student was marked Present just now.
  marked,

  /// A record existed as Absent/Late/Leave and was corrected to Present.
  updated,

  /// The student was already Present today; nothing changed.
  already,

  /// The pass was checked but no attendance was touched. Only happens for
  /// non-coach scanners, so a coach should never see this.
  verified;

  static CoachScanOutcome? tryParse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'marked':
        return CoachScanOutcome.marked;
      case 'updated':
        return CoachScanOutcome.updated;
      case 'already':
        return CoachScanOutcome.already;
      case 'verified':
        return CoachScanOutcome.verified;
      default:
        return null;
    }
  }

  /// Whether this scan actually changed today's attendance.
  bool get didMark =>
      this == CoachScanOutcome.marked || this == CoachScanOutcome.updated;
}

/// A successful scan.
///
/// The two ways a scan can fail both come back as HTTP errors, not as a
/// variant of this: an unknown code is a 404, and an enrollment that is not
/// yet `Approved` is a 409 naming the current approval status.
class CoachPassScan {
  const CoachPassScan({
    this.passCode = '',
    this.outcomeRaw,
    this.message,
    this.date,
    this.checkInTime,
    this.studentName = '',
    this.studentPhone = '',
    this.bloodGroup = '',
    this.dob,
    this.avatar,
    this.batchName = '',
    this.sportName = '',
    this.sportImage,
    this.coachName = '',
    this.batchDays = '',
    this.startTime = '',
    this.endTime = '',
  });

  /// Re-issued by the backend in its canonical `GATEPASS-YYYY-000042` form,
  /// which may differ from whatever the camera actually read.
  final String passCode;

  final String? outcomeRaw;

  /// The backend's own sentence, already phrased for display — e.g.
  /// `"Entry granted — Riya Shah marked Present."`. Preferred over anything
  /// composed on the client so the app and the gate terminal say the same
  /// thing.
  final String? message;

  /// `yyyy-MM-dd` the attendance was marked for.
  final String? date;

  /// `HH:mm:ss`. On an `already` outcome this is the **original** check-in
  /// time, not the time of this scan.
  final String? checkInTime;

  final String studentName;
  final String studentPhone;
  final String bloodGroup;
  final String? dob;
  final String? avatar;

  final String batchName;
  final String sportName;
  final String? sportImage;
  final String coachName;
  final String batchDays;
  final String startTime;
  final String endTime;

  CoachScanOutcome? get outcome => CoachScanOutcome.tryParse(outcomeRaw);

  bool get didMark => outcome?.didMark ?? false;

  String get displayName =>
      studentName.trim().isEmpty ? 'Student' : studentName.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  /// `"Mon, Wed, Fri · 6:00 - 7:00"`, skipping whichever part is missing.
  String get scheduleLabel {
    final time = [startTime.trim(), endTime.trim()]
        .where((part) => part.isNotEmpty)
        .join(' - ');
    return [
      if (batchDays.trim().isNotEmpty) batchDays.trim(),
      if (time.isNotEmpty) time,
    ].join(' · ');
  }

  @override
  String toString() =>
      'CoachPassScan($passCode, $studentName, ${outcomeRaw ?? '?'})';
}
