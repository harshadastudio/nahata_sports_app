import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/event_pass.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/sport.dart';
import '../../domain/repositories/coupons_repository.dart';
import '../../domain/repositories/event_pass_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../datasources/coupon_remote_data_source.dart';
import '../models/coupon_admin_model.dart';
import 'event_pass_repository_impl.dart';
import 'sport_repository_impl.dart';

/// [CouponsRepository] over the JWT backend.
///
/// The sport, venue and event lists are delegated to the modules that already
/// own them rather than re-fetched here, so the coupon form and the rest of
/// the console cannot disagree about what exists.
class CouponsRepositoryImpl implements CouponsRepository {
  CouponsRepositoryImpl({
    CouponRemoteDataSource? remote,
    SportsComplexRepository? complexes,
    SportRepository? sports,
    EventPassRepository? events,
  }) : _remote = remote ?? CouponRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance,
       _sports = sports ?? SportRepositoryImpl(),
       _events = events ?? EventPassRepositoryImpl();

  final CouponRemoteDataSource _remote;
  final SportsComplexRepository _complexes;
  final SportRepository _sports;
  final EventPassRepository _events;

  /// Events are fetched for a dropdown, so one generous page is enough — the
  /// form is not a browser for them.
  static const int _eventPageSize = 100;

  @override
  Future<Paged<AdminCoupon>> getCoupons({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    if (!response.isOk) throw response.toException();

    final result = CouponMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfUnreadable(
      rows: CouponMapper.rowsIn(response.data),
      parsed: result.items.length,
      body: response.data,
    );

    AdminLog.data('Coupons → $result');
    return result;
  }

  @override
  Future<AdminCoupon> getCouponById(int id) async {
    final response = await _remote.detail(id);
    if (!response.isOk) throw response.toException();

    final coupon = CouponMapper.maybeFromBody(response.data);
    if (coupon == null) {
      throw const ParseException('The server did not return this coupon.');
    }

    AdminLog.data('Coupon detail → $coupon');
    return coupon;
  }

  @override
  Future<AdminCoupon?> getCouponByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;

    try {
      final response = await _remote.byCode(trimmed);
      if (!response.isOk) return null;

      final coupon = CouponMapper.maybeFromBody(response.data);
      AdminLog.data('Coupon by code $trimmed → ${coupon ?? 'none'}');
      return coupon;
    } on NotFoundException {
      // "No coupon with this code" is the answer the create form wants, not a
      // failure it should surface.
      AdminLog.data('No coupon carries the code $trimmed');
      return null;
    }
  }

  @override
  Future<AdminCoupon> createCoupon(CouponDraft draft) async {
    final body = draft.toCreateJson();
    _assertValid(body, isCreate: true);

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = CouponMapper.maybeFromBody(response.data);
    AdminLog.success('Created coupon ${created?.code ?? '(code not echoed)'}');

    // A create that does not echo the row is still a success — the reload that
    // follows picks it up.
    return created ??
        AdminCoupon(
          id: 0,
          code: body['code'] as String?,
          discountTypeRaw: body['discountType'] as String?,
          discountValue: body['discountValue'] as num?,
          appliesToRaw: body['appliesTo'] as String?,
          platformRaw: body['platform'] as String?,
          statusRaw: body['status'] as String?,
        );
  }

  @override
  Future<AdminCoupon> updateCoupon(int id, CouponDraft draft) async {
    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }
    _assertValid(body, isCreate: false);

    final response = await _remote.update(id, body);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Updated coupon $id');
    return CouponMapper.maybeFromBody(response.data) ?? AdminCoupon(id: id);
  }

  @override
  Future<void> deleteCoupon(int id) async {
    final response = await _remote.remove(id);
    if (!response.isOk) throw response.toException();
    AdminLog.success('Deleted coupon $id');
  }

  @override
  Future<CouponCheck> validateCoupon({
    required String code,
    required num amount,
    required CouponAppliesTo appliesTo,
    int? sportComplexId,
    int? sportId,
    int? eventPassId,
  }) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Enter a coupon code.');
    }
    if (amount <= 0) {
      throw const ValidationException(
        'Enter the amount the coupon should apply to.',
      );
    }

    // Every documented key travels, nulls included — an absent key is not the
    // same as a null one to a validator that reads the scope positionally.
    final body = <String, dynamic>{
      'code': trimmed.toUpperCase(),
      'amount': amount is int ? amount : amount.round(),
      'appliesTo': appliesTo.slug,
      'sportComplexId': appliesTo.isCourt ? sportComplexId : null,
      'sportId': appliesTo.isCourt ? sportId : null,
      'eventPassId': appliesTo.isCourt ? null : eventPassId,
    };

    try {
      final response = await _remote.validate(body);

      final check = CouponMapper.checkFrom(
        response.data,
        isValid: response.isOk,
        fallbackMessage: response.isOk
            ? 'Coupon applied.'
            : 'This coupon cannot be used here.',
      );

      AdminLog.data('Validate $trimmed → $check');
      return check;
    } on ApiException catch (error) {
      if (!_isRejection(error)) rethrow;

      // A refused coupon is the server judging the coupon, not a failure of
      // the call — the desk sees the reason rather than an error screen.
      AdminLog.data('Coupon $trimmed rejected: ${error.message}');
      return CouponCheck.invalid(error.message);
    }
  }

  @override
  Future<List<AdminCoupon>> getActiveCoupons({
    CouponAppliesTo? appliesTo,
  }) async {
    final response = await _remote.active(appliesTo: appliesTo?.slug);
    if (!response.isOk) throw response.toException();

    final coupons = CouponMapper.listFrom(response.data);
    AdminLog.data('Active coupons → ${coupons.length}');
    return coupons;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    // `includeHidden` so a coupon can be scoped to a venue that is not
    // currently shown on the storefront.
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for coupons module → ${complexes.length}');
    return complexes;
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    final sports = await _sports.fetchSports();
    AdminLog.data('Sports for coupons module → ${sports.length}');
    return sports;
  }

  @override
  Future<List<AdminEventPass>> fetchEventPasses({bool refresh = false}) async {
    final page = await _events.fetchEventPasses(page: 1, limit: _eventPageSize);
    AdminLog.data('Events for coupons module → ${page.items.length}');
    return page.items;
  }

  /// Refuses a body the server could only reject.
  ///
  /// Runs against the serialised body rather than the draft so the two write
  /// paths cannot drift: whatever is about to be posted is what is checked.
  static void _assertValid(
    Map<String, dynamic> body, {
    required bool isCreate,
  }) {
    final code = body['code'] as String?;
    if (isCreate && (code == null || code.isEmpty)) {
      throw const ValidationException('Enter a coupon code.');
    }
    if (code != null && code.isNotEmpty && code.length < 3) {
      throw const ValidationException(
        'A coupon code needs at least 3 characters.',
      );
    }

    final type = body['discountType'] as String?;
    if (isCreate && type == null) {
      throw const ValidationException('Pick a discount type.');
    }

    final value = body['discountValue'] as num?;
    if (isCreate && value == null) {
      throw const ValidationException('Enter the discount value.');
    }
    if (value != null && value <= 0) {
      throw const ValidationException('The discount must be more than zero.');
    }
    if (value != null &&
        value > 100 &&
        CouponDiscountType.tryParse(type) == CouponDiscountType.percentage) {
      // 110% off would pay the customer to book.
      throw const ValidationException(
        'A percentage discount cannot be more than 100.',
      );
    }

    if (isCreate && body['validUntil'] == null) {
      throw const ValidationException('Pick the date the coupon expires.');
    }

    final limit = body['usageLimit'] as int?;
    if (limit != null && limit < 0) {
      throw const ValidationException('The usage limit cannot be negative.');
    }

    final max = body['maxDiscount'] as num?;
    if (max != null && max <= 0) {
      throw const ValidationException(
        'The maximum discount must be more than zero.',
      );
    }

    // One scope only. The draft already nulls the other side, so a body
    // carrying both means a caller built it by hand.
    if (body['eventPassId'] != null &&
        (body['sportComplexId'] != null || body['sportId'] != null)) {
      throw const ValidationException(
        'A coupon applies to a court booking or to an event, not both.',
      );
    }
  }

  /// True when the failure is the server judging the *coupon*, rather than a
  /// problem with the session, the network or the server itself.
  static bool _isRejection(ApiException error) {
    return error is BadRequestException ||
        error is NotFoundException ||
        error is ConflictException ||
        error is ValidationException;
  }

  /// Says in the log which kind of empty an empty list was, and names the keys
  /// it did see so a mapper fix is one edit away.
  static void _warnIfUnreadable({
    required List<Map<String, dynamic>> rows,
    required int parsed,
    required Object? body,
  }) {
    if (parsed > 0) return;

    if (rows.isEmpty) {
      final keys = body is Map ? body.keys.toList() : const <String>[];
      AdminLog.data(
        'No coupons in the response. Top-level keys: $keys — if the list is '
        'under one of these, add it to CouponMapper.listKeys.',
      );
      return;
    }

    AdminLog.failure(
      '${rows.length} coupon rows were returned but none carried a readable '
      'id, so all were dropped. Row keys: ${rows.first.keys.toList()}',
    );
  }
}
