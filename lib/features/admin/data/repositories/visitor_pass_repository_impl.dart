import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../../../repositories/sports_complex_repository.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/visitor_pass.dart';
import '../../domain/repositories/visitor_pass_repository.dart';
import '../datasources/visitor_pass_remote_data_source.dart';
import '../models/visitor_pass_model.dart';

/// [VisitorPassRepository] over the JWT backend.
class VisitorPassRepositoryImpl implements VisitorPassRepository {
  VisitorPassRepositoryImpl({
    VisitorPassRemoteDataSource? remote,
    SportsComplexRepository? complexes,
  }) : _remote = remote ?? VisitorPassRemoteDataSource(),
       _complexes = complexes ?? SportsComplexRepository.instance;

  final VisitorPassRemoteDataSource _remote;
  final SportsComplexRepository _complexes;

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final response = await _remote.list(
      page: page,
      limit: limit,
      search: search,
    );
    if (!response.isOk) throw response.toException();

    final result = VisitorPassMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfUnreadable(
      rows: VisitorPassMapper.rowsIn(response.data),
      parsed: result.items.length,
      body: response.data,
    );

    AdminLog.data('Visitor passes → $result');
    return result;
  }

  @override
  Future<VisitorPass> fetchVisitorPass(String idOrCode) async {
    final reference = idOrCode.trim();
    if (reference.isEmpty) {
      throw const ValidationException('No pass was selected.');
    }

    final response = await _remote.detail(reference);
    if (!response.isOk) throw response.toException();

    final pass = VisitorPassMapper.maybeFromBody(response.data);
    if (pass == null) {
      throw const ParseException(
        'The server did not return this visitor pass.',
      );
    }

    AdminLog.data('Visitor pass detail → $pass');
    return pass;
  }

  @override
  Future<VisitorPass> createVisitorPass(VisitorPassDraft draft) async {
    final body = draft.toJson();

    // Fail before the round trip rather than let the server reject a body it
    // could never accept.
    if ((body['visitorName'] as String).isEmpty) {
      throw const ValidationException("Enter the visitor's name.");
    }
    final phone = body['phoneNumber'] as String;
    if (phone.isEmpty) {
      throw const ValidationException('Enter a phone number.');
    }
    if (phone.length != 10) {
      throw const ValidationException(
        'The phone number must be exactly 10 digits.',
      );
    }
    if ((body['visitPurpose'] as String).isEmpty) {
      throw const ValidationException('Enter the purpose of the visit.');
    }
    if (body['sportComplexId'] == null) {
      throw const ValidationException('Pick a sports complex.');
    }

    final response = await _remote.create(body);
    if (!response.isOk) throw response.toException();

    final created = VisitorPassMapper.maybeFromBody(response.data);
    if (created == null) {
      // Without the echoed pass there is no code and no QR to show, which is
      // the whole point of generating one — so this counts as a failure even
      // though the HTTP call succeeded.
      throw const ServerException(
        'The pass was created but the server did not return its code.',
      );
    }

    AdminLog.success('Created visitor pass ${created.reference}');
    return created;
  }

  @override
  Future<VisitorPassCheck> verifyPass({
    required String passCode,
    required VisitorScanType scanType,
  }) async {
    final code = passCode.trim();
    if (code.isEmpty) {
      throw const ValidationException('Enter or scan a pass code.');
    }

    try {
      final response = await _remote.verify(
        passCode: code,
        scanType: scanType.slug,
      );

      // A 2xx that says `success: false` is a refusal, not a transport
      // failure — it is reported, with its reason, rather than thrown.
      final check = VisitorPassMapper.checkFrom(
        response.data,
        readOnly: false,
        success: response.isOk,
        scanType: scanType,
        fallbackMessage: response.isOk
            ? '${scanType.label} recorded.'
            : 'This pass could not be ${scanType == VisitorScanType.checkIn ? 'checked in' : 'checked out'}.',
      );

      if (check.success) {
        AdminLog.success('Verify ${scanType.slug} ok for $code');
        return check;
      }

      AdminLog.failure(
        'Verify ${scanType.slug} refused for $code: '
        '${check.message}',
      );
      return _enrich(check, code);
    } on ApiException catch (error) {
      if (!_isRefusal(error)) rethrow;

      // The gate still has to see who this is and where the pass stands, and a
      // 4xx body does not survive the typed exception — so the read-only twin
      // is asked for the current state. It cannot change the pass.
      AdminLog.failure(
        'Verify ${scanType.slug} rejected for $code: '
        '${error.message}',
      );

      return _enrich(
        VisitorPassCheck(
          success: false,
          readOnly: false,
          message: error.message,
          scanType: scanType,
        ),
        code,
      );
    }
  }

  @override
  Future<VisitorPassCheck> lookupPass(String passCode) async {
    final code = passCode.trim();
    if (code.isEmpty) {
      throw const ValidationException('Enter or scan a pass code.');
    }

    try {
      final response = await _remote.lookup(code);

      final check = VisitorPassMapper.checkFrom(
        response.data,
        readOnly: true,
        success: response.isOk,
        fallbackMessage: response.isOk
            ? null
            : 'This pass could not be verified.',
      );

      AdminLog.data('Lookup $code → $check');
      return check;
    } on ApiException catch (error) {
      if (!_isRefusal(error)) rethrow;

      AdminLog.failure('Lookup rejected for $code: ${error.message}');
      return VisitorPassCheck(
        success: false,
        readOnly: true,
        message: error.message,
        valid: false,
      );
    }
  }

  @override
  Future<String> sendPassEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  }) async {
    final reference = idOrCode.trim();
    if (reference.isEmpty) {
      throw const ValidationException('This pass has no id to send.');
    }

    final email = recipientEmail.trim();
    final name = recipientName.trim();

    if (name.isEmpty) {
      throw const ValidationException("Enter the recipient's name.");
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
      throw const ValidationException('Enter a valid email address.');
    }

    final response = await _remote.sendEmail(
      idOrCode: reference,
      recipientEmail: email,
      recipientName: name,
    );
    if (!response.isOk) throw response.toException();

    AdminLog.success('Emailed visitor pass $reference to $email');
    return response.message ?? 'Visitor Pass sent successfully.';
  }

  @override
  Future<void> deleteVisitorPass(String idOrCode) async {
    final reference = idOrCode.trim();
    if (reference.isEmpty) {
      throw const ValidationException('No pass was selected.');
    }

    final response = await _remote.remove(reference);
    if (!response.isOk) throw response.toException();

    AdminLog.success('Deleted visitor pass $reference');
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    // `includeHidden` so a pass can be issued for a venue that is not currently
    // shown on the storefront.
    final complexes = await _complexes.fetchComplexes(
      refresh: refresh,
      includeHidden: true,
    );
    AdminLog.data('Complexes for visitor passes → ${complexes.length}');
    return complexes;
  }

  /// Fills in the visitor's details and current status on a refused scan, using
  /// the read-only lookup.
  ///
  /// Best effort: if the lookup fails too, the refusal is returned exactly as
  /// it was — the reason is never dropped.
  Future<VisitorPassCheck> _enrich(VisitorPassCheck check, String code) async {
    if (check.pass != null && (check.pass!.statusRaw ?? '').isNotEmpty) {
      return check;
    }

    try {
      final looked = await _remote.lookup(code);
      final resolved = VisitorPassMapper.maybeFromBody(looked.data);
      if (resolved == null) return check;

      AdminLog.data('Refusal enriched from lookup → $resolved');
      return VisitorPassCheck(
        success: check.success,
        readOnly: check.readOnly,
        message: check.message,
        pass: check.pass ?? resolved,
        scanType: check.scanType,
        valid: check.valid,
      );
    } catch (error) {
      AdminLog.failure('Could not enrich the refusal for $code', error: error);
      return check;
    }
  }

  /// True when the failure is the server judging the *pass*, rather than a
  /// problem with the session, the network or the server itself.
  ///
  /// Only these are turned into a displayable result; everything else still
  /// propagates so the console can react to it as it always does (a session
  /// expiry must reach the auth layer, not be shown as "invalid pass").
  static bool _isRefusal(ApiException error) {
    return error is BadRequestException ||
        error is NotFoundException ||
        error is ConflictException ||
        error is ValidationException;
  }

  /// Says in the log which kind of empty an empty list was.
  ///
  /// No response for these routes was ever captured, so "there are no passes"
  /// and "this mapper could not read the rows" look identical on screen. This
  /// tells them apart and names the keys it did see, so the fix is one edit.
  static void _warnIfUnreadable({
    required List<Map<String, dynamic>> rows,
    required int parsed,
    required Object? body,
  }) {
    if (parsed > 0) return;

    if (rows.isEmpty) {
      final keys = body is Map ? body.keys.toList() : const <String>[];
      AdminLog.data(
        'No visitor passes in the response. Top-level keys: $keys — if the '
        'list is under one of these, add it to VisitorPassMapper.listKeys.',
      );
      return;
    }

    AdminLog.failure(
      '${rows.length} visitor-pass rows were returned but none carried a '
      'readable id or pass code, so all were dropped. Row keys: '
      '${rows.first.keys.toList()}',
    );
  }
}
