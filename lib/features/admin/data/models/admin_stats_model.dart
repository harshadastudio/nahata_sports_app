import '../../domain/entities/admin_stats.dart';
import 'json_reader.dart';

/// Maps `GET /admin/stats` onto [AdminStats].
class AdminStatsMapper {
  const AdminStatsMapper._();

  static AdminStats fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final total = JsonReader.integer(source, const [
      'totalUsers',
      'total_users',
      'users',
      'usersCount',
    ]);
    final verified = JsonReader.integer(source, const [
      'verifiedUsers',
      'verified_users',
      'verified',
    ]);
    var unverified = JsonReader.integer(source, const [
      'unverifiedUsers',
      'unverified_users',
      'unverified',
      'pendingVerification',
    ]);

    // Derive the third figure only when two of them are known — never invent
    // one from a single counter.
    if (unverified == null && total != null && verified != null) {
      final derived = total - verified;
      if (derived >= 0) unverified = derived;
    }

    return AdminStats(
      totalUsers: total,
      verifiedUsers: verified,
      unverifiedUsers: unverified,
      totalCoaches: JsonReader.integer(source, const [
        'totalCoaches',
        'total_coaches',
        'coaches',
        'coachesCount',
      ]),
      employees: JsonReader.integer(source, const [
        'employees',
        'totalEmployees',
        'total_employees',
        'employeesCount',
      ]),
      securityGuards: JsonReader.integer(source, const [
        'securityGuards',
        'security_guards',
        'guards',
        'totalSecurityGuards',
      ]),
      admins: JsonReader.integer(source, const [
        'admins',
        'totalAdmins',
        'total_admins',
        'adminsCount',
      ]),
      raw: source,
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['stats', 'data', 'result', 'summary']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        final nested = unwrapped['stats'];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        return unwrapped;
      }
    }
    return json;
  }
}
