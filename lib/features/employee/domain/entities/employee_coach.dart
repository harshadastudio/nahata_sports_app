import 'employee_formats.dart';

/// A coach at the employee's complex, from `GET /coaches`.
///
/// **Read-only.** Creating and editing a coach is an admin route; the employee
/// menu offers this so the desk can look up who runs a batch and how to reach
/// them, which is what the website's Coaches Management does too.
///
/// The response has two shapes depending on how the row was loaded — a flat
/// `{name, email, phone}` and a nested `{user: {name, email, phone_number}}` —
/// so the mapper reads both and this entity holds only the resolved values.
class EmployeeCoach {
  const EmployeeCoach({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.status = 'Active',
    this.bio,
    this.experience,
    this.sports = const [],
    this.joinedAt,
  });

  final int id;
  final String name;
  final String email;
  final String phone;

  /// `Active` | `Inactive`. Derived from `isActive` when the row sends a
  /// boolean instead of a word.
  final String status;

  final String? bio;

  /// Years, as sent — a string on some rows, a number on others.
  final String? experience;

  /// Sport names, already flattened out of whichever of the two shapes the row
  /// used (`[{id, name}]` or `["Badminton"]`).
  final List<String> sports;

  final DateTime? joinedAt;

  String get displayName => name.trim().isEmpty ? 'Coach #$id' : name.trim();

  /// Up to two initials — `Ravi Kumar` → `RK`.
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    final letters = parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return letters.isEmpty ? '?' : letters;
  }

  bool get isActive => status.toLowerCase() == 'active';

  String get sportsLabel => sports.isEmpty ? '—' : sports.join(', ');

  String get joinedLabel => formatDay(joinedAt);

  @override
  String toString() => 'EmployeeCoach($id, $displayName, $status)';
}
