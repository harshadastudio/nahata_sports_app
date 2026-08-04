/// The counters behind the dashboard home cards (`GET /admin/stats`).
///
/// Every counter is nullable: a card for a figure the server did not send shows
/// "—" rather than a fabricated zero.
class AdminStats {
  const AdminStats({
    this.totalUsers,
    this.verifiedUsers,
    this.unverifiedUsers,
    this.totalCoaches,
    this.employees,
    this.securityGuards,
    this.admins,
    this.raw = const {},
  });

  final int? totalUsers;
  final int? verifiedUsers;
  final int? unverifiedUsers;
  final int? totalCoaches;
  final int? employees;
  final int? securityGuards;
  final int? admins;

  /// The untouched payload, so counters this entity does not model are still
  /// available to whatever module needs them next.
  final Map<String, dynamic> raw;

  static const AdminStats empty = AdminStats();

  bool get isEmpty =>
      totalUsers == null &&
      verifiedUsers == null &&
      unverifiedUsers == null &&
      totalCoaches == null &&
      employees == null &&
      securityGuards == null &&
      admins == null;

  bool get isNotEmpty => !isEmpty;

  /// Share of users that are verified, or null when it cannot be computed.
  double? get verifiedRatio {
    final total = totalUsers;
    final verified = verifiedUsers;
    if (total == null || verified == null || total <= 0) return null;
    return (verified / total).clamp(0.0, 1.0);
  }

  @override
  String toString() =>
      'AdminStats(users: $totalUsers, verified: $verifiedUsers, '
      'unverified: $unverifiedUsers, coaches: $totalCoaches, '
      'employees: $employees, guards: $securityGuards, admins: $admins)';
}
