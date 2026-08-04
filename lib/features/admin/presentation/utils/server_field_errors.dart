import '../../../../core/network/api_exception.dart';

/// A column the database rejected a value for, read out of the error message.
class RejectedValue {
  const RejectedValue({required this.field, required this.value, this.label});

  /// The payload key, e.g. `assignedArea`.
  final String field;

  /// The value the server refused, e.g. `Backgate`.
  final String value;

  /// A human name for the column, e.g. `Assigned area`.
  final String? label;

  String get fieldLabel => label ?? _humanise(field);

  String get message =>
      '"$value" is not one of the values this backend accepts for '
      '${fieldLabel.toLowerCase()}.';

  /// `assignedArea` → `Assigned area`.
  static String _humanise(String field) {
    final spaced = field
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => ' ${m[1]}')
        .trim();
    if (spaced.isEmpty) return field;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }

  @override
  String toString() => 'RejectedValue($field: "$value")';
}

/// Field-level errors for a form, from whatever the server actually sent.
///
/// The admin API sometimes returns a structured `errors` map, and sometimes
/// only a `message` — including database constraint errors that name the column
/// and the offending value but never appear in `errors`:
///
/// ```
/// invalid input value for enum "enum_SecurityGuards_assignedArea": "Backgate"
/// ```
///
/// Left unparsed, that lands in the form's banner and nowhere near the box that
/// caused it. This reads the column out of the message so the error can be
/// shown against the right field, and reports the rejected value so the form
/// can refuse to send it again unchanged.
class ServerFieldErrors {
  const ServerFieldErrors({
    this.fields = const {},
    this.rejected,
    this.summary,
  });

  static const ServerFieldErrors none = ServerFieldErrors();

  /// Payload key → message.
  final Map<String, String> fields;

  /// Set when the message named a column and the value it refused.
  final RejectedValue? rejected;

  /// A clearer replacement for the raw server message, when one can be made.
  final String? summary;

  bool get isEmpty => fields.isEmpty && rejected == null;

  String? operator [](String key) => fields[key];

  /// First match among [keys], for a field that has been spelled more than one
  /// way across routes (`assignedArea` / `assigned_area`).
  String? forKeys(List<String> keys) {
    for (final key in keys) {
      final message = fields[key];
      if (message != null) return message;
    }
    return null;
  }

  static ServerFieldErrors from(ApiException error, {String? fieldLabel}) {
    final fields = _readErrorsMap(error.errors);
    final rejected = parseRejectedValue(error.message, label: fieldLabel);

    if (rejected == null) {
      return ServerFieldErrors(fields: fields);
    }

    return ServerFieldErrors(
      // A structured error for the same field wins: it is the server being
      // explicit rather than this class inferring from prose.
      fields: {rejected.field: rejected.message, ...fields},
      rejected: rejected,
      summary: rejected.message,
    );
  }

  /// Reads a Postgres enum or check-constraint rejection out of a message.
  ///
  /// Matches the two shapes this backend produces:
  /// * `invalid input value for enum "enum_SecurityGuards_assignedArea":
  ///   "Backgate"`
  /// * `invalid input value for enum enum_Table_column: Backgate`
  ///
  /// Returns null for anything else, so an ordinary message is never mangled
  /// into a field error it does not belong to.
  static RejectedValue? parseRejectedValue(String message, {String? label}) {
    final match = RegExp(
      r'invalid input value for enum\s+"?([\w.]+)"?\s*:\s*"?([^"\n]*?)"?\s*$',
      caseSensitive: false,
    ).firstMatch(message.trim());

    if (match == null) return null;

    final enumName = match.group(1) ?? '';
    final value = (match.group(2) ?? '').trim();
    final field = _columnOf(enumName);

    if (field.isEmpty || value.isEmpty) return null;
    return RejectedValue(field: field, value: value, label: label);
  }

  /// `enum_SecurityGuards_assignedArea` → `assignedArea`.
  ///
  /// Sequelize names an enum type `enum_<Table>_<column>`, so the column is
  /// everything after the second underscore — a column that itself contains an
  /// underscore (`assigned_area`) therefore survives intact.
  static String _columnOf(String enumName) {
    final parts = enumName.split('_');
    if (parts.length < 3) return '';
    return parts.sublist(2).join('_');
  }

  static Map<String, String> _readErrorsMap(Map<String, dynamic>? errors) {
    if (errors == null) return const {};
    final result = <String, String>{};
    errors.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        result[key] = value.first.toString();
      } else if (value != null) {
        result[key] = value.toString();
      }
    });
    return result;
  }
}
