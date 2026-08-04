import '../../domain/entities/complex_admin.dart';
import '../../domain/entities/paged.dart';
import 'json_reader.dart';

/// Maps `/admin/complex-admins` JSON onto [ComplexAdmin].
class ComplexAdminMapper {
  const ComplexAdminMapper._();

  static ComplexAdmin fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    // The venue may arrive as a nested object, a bare name, or just an id.
    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);

    return ComplexAdmin(
      // Top-level only: where the row embeds a `user`, inheriting its `id`
      // would address the wrong record. `userId` stays in the list because a
      // complex admin genuinely may be keyed by it — but only when the row
      // itself says so.
      id:
          JsonReader.ownString(source, const [
            'id',
            '_id',
            'complexAdminId',
            'userId',
          ]) ??
          '',
      name: JsonReader.string(source, const ['name', 'fullName', 'full_name']),
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      phone: JsonReader.string(source, const [
        'phone_number',
        'phoneNumber',
        'phone',
        'mobile',
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
      city:
          JsonReader.string(source, const ['city', 'location']) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['city', 'location'])),
      statusRaw: JsonReader.string(source, const ['status', 'accountStatus']),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdDate',
        'joinDate',
      ]),
      raw: source,
    );
  }

  static List<ComplexAdmin> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'complexAdmins',
            'complex_admins',
            'admins',
            'items',
            'data',
            'results',
          ],
        )
        .map(fromJson)
        .where((admin) => admin.id.isNotEmpty)
        .toList(growable: false);
  }

  /// Builds the page. When the backend does not paginate, the meta block is
  /// absent and the whole list is reported as page 1 of 1 — which is exactly
  /// what it is.
  static Paged<ComplexAdmin> pageFrom(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = listFrom(body);
    final meta = JsonReader.meta(body);

    final total =
        JsonReader.integer(meta, const [
          'total',
          'totalItems',
          'totalRecords',
          'count',
        ]) ??
        items.length;

    final totalPages =
        JsonReader.integer(meta, const [
          'totalPages',
          'total_pages',
          'pageCount',
          'lastPage',
        ]) ??
        0;

    return Paged<ComplexAdmin>(
      items: items,
      page:
          JsonReader.integer(meta, const ['page', 'currentPage']) ??
          fallbackPage,
      limit:
          JsonReader.integer(meta, const ['limit', 'perPage', 'pageSize']) ??
          fallbackLimit,
      total: total,
      totalPages: totalPages,
    );
  }

  static ComplexAdmin? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final admin = fromJson(Map<String, dynamic>.from(body));
    return admin.id.isEmpty ? null : admin;
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
    // `user` is deliberately absent — see SecurityGuardMapper._unwrap.
    for (final key in const [
      'complexAdmin',
      'admin',
      'data',
      'result',
    ]) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['complexAdmin', 'admin', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}
