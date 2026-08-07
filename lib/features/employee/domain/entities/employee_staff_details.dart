/// The admin-entered employment record behind an employee's login, from
/// `GET /auth/staff-details`.
///
/// Deliberately **untyped label/value pairs** rather than a class with an
/// `employeeId`, a `designation` and so on. The route answers the same envelope
/// for every staff role — an employee gets Employment Details, a coach gets
/// Coaching Details and Qualifications — and it drops fields whose value is
/// empty before sending. Modelling that as fixed fields would mean this side
/// deciding which are optional, re-doing the emptiness check, and needing a
/// change here every time the admin form gains a field.
///
/// Read-only: `PUT /auth/profile` answers 403 for staff logins, because an
/// admin maintains these details.
class EmployeeStaffField {
  const EmployeeStaffField({required this.label, required this.value});

  /// Already human-readable — `Employee ID`, `Joining Date`, `Sports Complex`.
  final String label;

  /// Already formatted. Dates arrive as `07 Aug 2026`, so nothing here parses
  /// or re-renders them.
  final String value;

  @override
  String toString() => 'EmployeeStaffField($label: $value)';
}

/// One titled block of [EmployeeStaffField]s.
class EmployeeStaffSection {
  const EmployeeStaffSection({required this.title, this.fields = const []});

  /// `Employment Details`, `Account`, …
  final String title;

  final List<EmployeeStaffField> fields;

  bool get isEmpty => fields.isEmpty;

  @override
  String toString() =>
      'EmployeeStaffSection($title, ${fields.length} fields)';
}

/// Everything the route returned.
class EmployeeStaffDetails {
  const EmployeeStaffDetails({this.role = '', this.sections = const []});

  /// The role the backend resolved from the token — `EMPLOYEE`, `COACH`.
  final String role;

  final List<EmployeeStaffSection> sections;

  static const EmployeeStaffDetails empty = EmployeeStaffDetails();

  /// True when there is genuinely nothing to show — an employee whose login has
  /// no `Employee` row behind it yet, which is a real state right after an
  /// admin creates the account.
  bool get isEmpty => sections.every((section) => section.isEmpty);

  @override
  String toString() => 'EmployeeStaffDetails($role, ${sections.length} sections)';
}
