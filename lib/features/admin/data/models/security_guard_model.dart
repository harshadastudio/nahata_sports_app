import '../../domain/entities/paged.dart';
import '../../domain/entities/security_guard.dart';
import 'json_reader.dart';

/// Maps `/admin/security-guards` JSON onto [SecurityGuard].
class SecurityGuardMapper {
  const SecurityGuardMapper._();

  static SecurityGuard fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);

    // The guard's badge number. Read first because it also stands in as the
    // record id when the payload carries no separate database id — every row
    // action is path-scoped, and a row with no usable id would be inert.
    final guardCode = JsonReader.ownString(source, const [
      'guardId',
      'guard_id',
      'guardCode',
      'badgeNumber',
      'employeeId',
    ]);

    return SecurityGuard(
      // Read top-level only. The row embeds a `user` object whose own `id`
      // is the *user* id (`{"id": 22, "userId": 585, "user": {"id": 585}}`),
      // and inheriting it would point every `/{guardId}` call at the wrong
      // record — a 404 at best, someone else's guard at worst.
      id:
          JsonReader.ownString(source, const ['id', '_id', 'guardDbId']) ??
          guardCode ??
          '',
      guardCode: guardCode,
      fullName: JsonReader.string(source, const [
        'fullName',
        'full_name',
        'name',
        'guardName',
      ]),
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      phone: JsonReader.string(source, const [
        'phone',
        'phoneNumber',
        'phone_number',
        'mobile',
      ]),
      licenseNumber: JsonReader.string(source, const [
        'licenseNumber',
        'license_number',
        'licenceNumber',
        'licenseNo',
      ]),
      assignedArea: JsonReader.string(source, const [
        'assignedArea',
        'assigned_area',
        'area',
        'postingArea',
      ]),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'sportsComplexId',
            'complexId',
          ]) ??
          (complex == null
              ? null
              : JsonReader.integer(complex, const ['id', '_id'])),
      sportComplexName:
          JsonReader.string(source, const [
            'sportComplexName',
            'sport_complex_name',
            'complexName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      sportComplexCity:
          JsonReader.string(source, const [
            'sportComplexCity',
            'sport_complex_city',
            'complexCity',
            'city',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['city', 'location'])),
      shiftRaw: JsonReader.string(source, const ['shift', 'shiftType']),
      salary: _number(source, const ['salary', 'monthlySalary', 'pay']),
      statusRaw: JsonReader.string(source, const ['status', 'accountStatus']),
      joiningDate: JsonReader.date(source, const [
        'joiningDate',
        'joining_date',
        'dateOfJoining',
        'joinDate',
        'createdAt',
      ]),
      raw: source,
    );
  }

  static List<SecurityGuard> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'securityGuards',
            'security_guards',
            'guards',
            'items',
            'data',
            'results',
            'records',
          ],
        )
        .map(fromJson)
        .where((guard) => guard.id.isNotEmpty)
        .toList(growable: false);
  }

  static Paged<SecurityGuard> pageFrom(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = listFrom(body);
    final meta = JsonReader.meta(body);

    return Paged<SecurityGuard>(
      items: items,
      page:
          JsonReader.integer(meta, const [
            'page',
            'currentPage',
            'current_page',
          ]) ??
          fallbackPage,
      limit:
          JsonReader.integer(meta, const [
            'limit',
            'perPage',
            'per_page',
            'pageSize',
          ]) ??
          fallbackLimit,
      total:
          JsonReader.integer(meta, const [
            'total',
            'totalItems',
            'totalRecords',
            'totalGuards',
            'totalSecurityGuards',
            'count',
          ]) ??
          items.length,
      totalPages:
          JsonReader.integer(meta, const [
            'totalPages',
            'total_pages',
            'pageCount',
            'lastPage',
          ]) ??
          0,
    );
  }

  static SecurityGuard? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final guard = fromJson(Map<String, dynamic>.from(body));
    return guard.id.isEmpty ? null : guard;
  }

  /// Salary arrives as `28000`, `28000.50` or `"28,000"`.
  static num? _number(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value;
    // Strip currency symbols and separators before parsing.
    final text = value.toString().trim().replaceAll(RegExp(r'[^\d.\-]'), '');
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }

  static Map<String, dynamic>? _nested(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    // `user` is deliberately absent from both lists. A guard row *embeds* the
    // person it belongs to, so descending into it would swap the guard record
    // for the user — losing the shift, area, salary, status and licence, and
    // taking the user id along with it. Display fields still resolve, because
    // JsonReader.pick looks inside a `user` envelope on its own.
    for (final key in const [
      'securityGuard',
      'security_guard',
      'guard',
      'data',
      'result',
    ]) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const [
          'securityGuard',
          'guard',
          'data',
        ]) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /admin/security-guards/{guardId}/password`.
class SecurityGuardCredentialsMapper {
  const SecurityGuardCredentialsMapper._();

  static SecurityGuardCredentials fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return SecurityGuardCredentials(
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      password: JsonReader.string(source, const [
        'temporaryPassword',
        'temporary_password',
        'tempPassword',
        'password',
        'plainPassword',
        'defaultPassword',
      ]),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['credentials', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return json;
  }
}
