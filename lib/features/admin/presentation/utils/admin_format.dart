import 'package:intl/intl.dart';

/// Display formatting for the dashboard.
///
/// Every "not sent by the server" case funnels through [dash] so a missing
/// value reads the same everywhere instead of appearing as an empty cell.
class AdminFormat {
  const AdminFormat._();

  static const String dash = '—';

  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM yyyy, h:mm a');
  static final NumberFormat _compact = NumberFormat.compact();
  static final NumberFormat _decimal = NumberFormat.decimalPattern();

  static String date(DateTime? value) =>
      value == null ? dash : _date.format(value.toLocal());

  static String dateTime(DateTime? value) =>
      value == null ? dash : _dateTime.format(value.toLocal());

  static String number(int? value) =>
      value == null ? dash : _decimal.format(value);

  /// `12.4K` for the stat cards, where width is tight.
  static String compact(int? value) =>
      value == null ? dash : _compact.format(value);

  static String text(String? value) {
    final trimmed = (value ?? '').trim();
    return trimmed.isEmpty ? dash : trimmed;
  }

  static String list(List<String> values) =>
      values.isEmpty ? dash : values.join(', ');

  /// "2 hours ago" style, for the Last Active column.
  static String relative(DateTime? value) {
    if (value == null) return dash;

    final now = DateTime.now();
    final local = value.toLocal();
    final difference = now.difference(local);

    if (difference.isNegative) return date(value);
    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    if (difference.inDays < 365) {
      return '${(difference.inDays / 7).floor()}w ago';
    }
    return date(value);
  }

  /// A percentage for the verified-users meter.
  static String percent(double? ratio) =>
      ratio == null ? dash : '${(ratio * 100).round()}%';

  /// A growth figure already expressed in percent (`12.5` → `+12.5%`).
  ///
  /// One decimal place only when it carries information, so `+12%` does not
  /// read as `+12.0%`. [signed] off drops the leading sign, for places where an
  /// arrow already shows the direction.
  static String growth(double? value, {bool signed = true}) {
    if (value == null) return dash;

    final rounded = (value.abs() * 10).round() / 10;
    final text = rounded == rounded.roundToDouble()
        ? rounded.round().toString()
        : rounded.toStringAsFixed(1);

    if (!signed) return '$text%';
    return '${value < 0 ? '-' : '+'}$text%';
  }

  /// A salary figure. Grouped in the Indian convention (`₹1,20,000`) because
  /// that is what the venues bill in; a value with paise keeps two decimals.
  static String currency(num? value) {
    if (value == null) return dash;
    final whole = value == value.roundToDouble();
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: whole ? 0 : 2,
    );
    return formatter.format(value);
  }

  /// A slice's share of the doughnut (`33.333` → `33.3%`).
  static String share(double? value) {
    if (value == null) return dash;
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.roundToDouble()
        ? '${rounded.round()}%'
        : '${rounded.toStringAsFixed(1)}%';
  }
}
