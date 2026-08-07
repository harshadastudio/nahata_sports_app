import 'gate_scan.dart';

/// Works out which gate a code belongs to.
///
/// The global search box takes any code a guard can present — a visitor pass, a
/// booking, an event ticket, a student gate pass — and has to send it to the
/// right scanner without asking. The four systems prefix their codes
/// differently, which is the only signal available client-side.
///
/// A code that matches nothing is **not** guessed at. [identify] returns null
/// and the caller asks the guard which gate it is, because sending an unknown
/// code to the wrong `/scan` route would spend a leg of somebody's real pass.
class PassCodeRouter {
  const PassCodeRouter._();

  /// Prefixes as the backends issue them, longest first so `GATEPASS-` is
  /// tested before any shorter overlap.
  static const Map<String, GateScanKind> _prefixes = {
    'GATEPASS': GateScanKind.coaching,
    'EVTPASS': GateScanKind.event,
    'EVENTPASS': GateScanKind.event,
    'BOOK': GateScanKind.courtBooking,
    'BOOKING': GateScanKind.courtBooking,
    'COURT': GateScanKind.courtBooking,
    'VP': GateScanKind.visitor,
    'NS': GateScanKind.visitor,
    'VISITOR': GateScanKind.visitor,
  };

  /// Pulls a code out of whatever the camera read.
  ///
  /// A QR often carries a URL or a JSON blob with the code inside it rather
  /// than the bare code, so the longest code-shaped token wins.
  static String? extract(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    // A bare code, already — the pattern has to span the *whole* string, or a
    // URL like `https://nahata.app/p/EVTPASS-1` would be taken as the code.
    final whole = _codePattern.matchAsPrefix(trimmed);
    if (whole != null && whole.end == trimmed.length) {
      return trimmed.toUpperCase();
    }

    final matches = _codePattern
        .allMatches(trimmed)
        .map((match) => match.group(0)!)
        .toList();
    if (matches.isEmpty) return null;

    matches.sort((a, b) => b.length.compareTo(a.length));
    return matches.first.toUpperCase();
  }

  /// `LETTERS-SEGMENT[-SEGMENT…]` — the shape all four systems use
  /// (`EVTPASS-2026-0003312`, `BOOK-2026-004021`, `VP-8FA23K`).
  ///
  /// A segment may be a single character: a venue that drops the zero padding
  /// still issues a real code, and truncating it would send the gate a code
  /// that matches nothing.
  static final RegExp _codePattern = RegExp(
    r'[A-Za-z]{2,12}(?:-[A-Za-z0-9]{1,20}){1,4}',
  );

  /// The gate a code belongs to, or null when nothing recognises it.
  static GateScanKind? identify(String code) {
    final normalised = code.trim().toUpperCase();
    if (normalised.isEmpty) return null;

    final head = normalised.split(RegExp(r'[-_/]')).first;
    if (head.isEmpty) return null;

    final direct = _prefixes[head];
    if (direct != null) return direct;

    // Some deployments prefix the venue ("NAHATA-EVTPASS-…"), so the whole
    // code is checked for a known marker as a second pass.
    for (final entry in _prefixes.entries) {
      if (normalised.contains('${entry.key}-')) return entry.value;
    }

    return null;
  }

  /// Extract and identify in one step, for the global search box.
  static ({String code, GateScanKind? kind})? resolve(String raw) {
    final code = extract(raw) ?? raw.trim().toUpperCase();
    if (code.isEmpty) return null;
    return (code: code, kind: identify(code));
  }
}