/// The fixed vocabularies the employee form and filters offer.
///
/// These are enumerated by the product spec rather than by any endpoint — there
/// is no `/departments` route to read them from — so they live here as the one
/// definition the form, the filters and the table all share. [slug] is what
/// goes on the wire; a value the server sends that is not in the list still
/// renders through `labelFor`, so the list being wrong never hides data.
enum Department {
  operations('Operations'),
  frontDesk('Front Desk'),
  maintenance('Maintenance'),
  housekeeping('Housekeeping'),
  accounts('Accounts'),
  customerService('Customer Service');

  const Department(this.slug);

  final String slug;

  String get label => slug;

  static Department? tryParse(Object? value) =>
      _match(Department.values, value);

  static String labelFor(String? raw) => tryParse(raw)?.label ?? _titleise(raw);
}

enum Designation {
  manager('Manager'),
  supervisor('Supervisor'),
  staff('Staff'),
  technician('Technician'),
  accountant('Accountant'),
  receptionist('Receptionist');

  const Designation(this.slug);

  final String slug;

  String get label => slug;

  static Designation? tryParse(Object? value) =>
      _match(Designation.values, value);

  static String labelFor(String? raw) => tryParse(raw)?.label ?? _titleise(raw);
}

/// Where a security guard is posted.
///
/// Unlike the three vocabularies above, this one is **not** from the product
/// spec — it is a database enum. Sending anything outside it comes back as
/// `invalid input value for enum "enum_SecurityGuards_assignedArea"` (400), so
/// the form offers these and nothing else.
///
/// The casing is deliberate: a live `POST /admin/security-guards` on
/// 2026-08-04 was accepted with `"Parking"` and echoed it back capitalised, so
/// the members are title-cased. Reads stay forgiving anyway — [_match] ignores
/// case and separators, so `parking` and `MAIN_GATES` both resolve — and a
/// value outside the list still renders through [labelFor] rather than
/// vanishing from the table.
enum AssignedArea {
  mainGates('Main Gates'),
  parking('Parking'),
  courts('Courts'),
  building('Building'),
  perimeter('Perimeter');

  const AssignedArea(this.slug);

  /// Exactly what goes on the wire.
  final String slug;

  String get label => slug;

  static AssignedArea? tryParse(Object? value) =>
      _match(AssignedArea.values, value);

  static String labelFor(String? raw) => tryParse(raw)?.label ?? _titleise(raw);
}

enum Shift {
  morning('Morning'),
  evening('Evening'),
  night('Night'),
  rotational('Rotational');

  const Shift(this.slug);

  final String slug;

  String get label => slug;

  static Shift? tryParse(Object? value) => _match(Shift.values, value);

  static String labelFor(String? raw) => tryParse(raw)?.label ?? _titleise(raw);
}

/// Case- and separator-insensitive lookup shared by the three vocabularies:
/// `FRONT_DESK`, `front desk` and `frontDesk` all resolve to `Front Desk`.
T? _match<T>(List<T> values, Object? raw) {
  if (raw == null) return null;
  final wanted = _normalise(raw.toString());
  if (wanted.isEmpty) return null;

  for (final value in values) {
    final slug = (value as dynamic).slug as String;
    if (_normalise(slug) == wanted) return value;
  }
  return null;
}

String _normalise(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

/// `front_desk` → `Front Desk`, for a value outside the known list.
String _titleise(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return '—';
  return text
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}
