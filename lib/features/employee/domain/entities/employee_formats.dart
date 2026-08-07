/// The formatting every employee screen shares.
///
/// These live with the entities rather than in a UI util file because the rules
/// are domain knowledge, not styling: Indian digit grouping, the `HH:mm:ss` the
/// API sends times in, and the `yyyy-MM-dd` every date filter and body field
/// expects back. Entities expose already-formatted labels so no two screens can
/// render the same field differently.

/// `₹1,20,500` — Indian digit grouping, no decimals.
///
/// `NumberFormat.currency` would need an `en_IN` locale the app does not
/// otherwise initialise, and would group in thousands without it — which is the
/// one thing that must not happen to a rupee figure.
String formatRupees(num? amount) {
  final value = (amount ?? 0).round();
  final negative = value < 0;
  final digits = value.abs().toString();

  final buffer = StringBuffer();
  if (digits.length <= 3) {
    buffer.write(digits);
  } else {
    // Last three digits, then pairs: "1234567" → "12,34,567".
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);

    final parts = <String>[];
    var rest = head;
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);

    buffer
      ..write(parts.join(','))
      ..write(',')
      ..write(tail);
  }

  return '${negative ? '-' : ''}₹$buffer';
}

/// `"14:30:00"` → `"2:30 PM"`. Null for an absent or unparseable time, so the
/// caller decides what "no time" should read as.
String? formatClock(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;

  final parts = text.split(':');
  final hour = int.tryParse(parts.first);
  if (hour == null) return null;

  final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final display = hour % 12 == 0 ? 12 : hour % 12;

  return '$display:${minute.toString().padLeft(2, '0')} $suffix';
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `07 Aug 2026`, or an em dash for a null date.
String formatDay(DateTime? date) {
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_months[date.month - 1]} ${date.year}';
}

/// `07 Aug 2026, 2:30 PM` — for records where the time of day is part of what
/// happened (an enquiry arriving, a notification being sent).
String formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  return '${formatDay(value)}, $hour:$minute $suffix';
}

/// `Just now` / `12 mins ago` / `3 hours ago` / `2 days ago`.
///
/// Falls back to the absolute date past a week — "43 days ago" is harder to
/// read than the date itself. A future timestamp (clock skew between the phone
/// and the server) also falls back rather than printing a negative age.
String formatRelative(DateTime? value) {
  if (value == null) return '—';

  final diff = DateTime.now().difference(value);
  if (diff.isNegative) return formatDay(value);

  final minutes = diff.inMinutes;
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '$minutes min${minutes == 1 ? '' : 's'} ago';

  final hours = diff.inHours;
  if (hours < 24) return '$hours hour${hours == 1 ? '' : 's'} ago';

  final days = diff.inDays;
  if (days <= 7) return '$days day${days == 1 ? '' : 's'} ago';

  return formatDay(value);
}

/// `2026-08-07` — the wire format every date filter and body field uses.
String formatIsoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// `2026-08` — the wire format for a month picker.
String formatIsoMonth(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';
