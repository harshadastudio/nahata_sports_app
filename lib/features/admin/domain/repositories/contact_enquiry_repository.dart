import '../entities/contact_inquiry.dart';

/// Reads the Contact Enquiries queue.
///
/// One interface for ADMIN and COMPLEX_ADMIN alike — the roles differ in what
/// the backend returns, not in how the console asks. If a venue-scoped endpoint
/// is ever confirmed, it belongs behind this same method.
abstract class ContactEnquiryRepository {
  /// One page of enquiries, with the dataset-wide status counts that came with
  /// it. Throws an `ApiException` on failure, as every repository here does.
  Future<ContactInquiryPage> fetchEnquiries({int page, int limit});
}