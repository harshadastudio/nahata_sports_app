import '../../../../core/api/complex_scope.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/contact_inquiry.dart';
import '../../domain/repositories/contact_enquiry_repository.dart';
import '../datasources/contact_enquiry_remote_data_source.dart';
import '../models/contact_inquiry_model.dart';

/// [ContactEnquiryRepository] over `GET /contact-us/admin`.
///
/// Shared by both administrative roles — see the data source for why there is
/// only one.
class ContactEnquiryRepositoryImpl implements ContactEnquiryRepository {
  ContactEnquiryRepositoryImpl({ContactEnquiryRemoteDataSource? remote})
    : _remote = remote ?? ContactEnquiryRemoteDataSource();

  final ContactEnquiryRemoteDataSource _remote;

  @override
  Future<ContactInquiryPage> fetchEnquiries({
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _remote.list(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = ContactInquiryMapper.pageFrom(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    // The backend scopes these rows from the JWT, so this changes nothing in
    // normal operation. It is a second line of defence for a payload that turns
    // out to be estate-wide: a row belonging to another venue is dropped, and a
    // row that reports no venue is kept — the server is still the authority.
    final rows = ComplexScope.restrict(
      result.items,
      (row) => row.effectiveComplexId,
    );

    if (rows.length != result.items.length) {
      AdminLog.data(
        'Contact enquiries → ${rows.length} of ${result.items.length} '
        '(venue-scoped to ${ComplexScope.id})',
      );
      // The counters describe the whole dataset the *server* answered for, so
      // they are left exactly as they arrived rather than being recomputed from
      // a shortened list — a derived total would be a different, quieter claim.
      return ContactInquiryPage(
        page: result.page.copyWith(items: rows),
        counts: result.counts,
      );
    }

    AdminLog.data(
      'Contact enquiries → ${rows.length} rows, page ${result.page.page}'
      '/${result.page.effectiveTotalPages}, counts ${result.counts}',
    );
    return result;
  }
}