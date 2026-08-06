import '../../../../models/sports_complex_model.dart';
import '../entities/coach.dart';
import '../entities/coaching_enquiry.dart';
import '../entities/paged.dart';
import '../entities/sport.dart';

/// The coaching-enquiry desk: the queue, the follow-up, and the counters.
///
/// Rules the implementation enforces before anything leaves the device,
/// because the server can only answer with a rejection:
///
/// * name, phone, email, sport, complex and message are all required to log an
///   enquiry, and the phone must be exactly ten digits,
/// * an update has to change something,
/// * a status has to be one of the five the module documents.
abstract class CoachingEnquiryRepository {
  /// `GET /coaching-enquiries?page=&limit=`
  Future<Paged<CoachingEnquiry>> getEnquiries({
    int page,
    int limit,
    String? search,
    CoachingEnquiryStatus? status,
  });

  /// `GET /coaching-enquiries/{enquiryId}`
  Future<CoachingEnquiry> getEnquiry(int id);

  /// `POST /coaching-enquiries`
  Future<CoachingEnquiry> createEnquiry(CoachingEnquiryDraft draft);

  /// `PUT /coaching-enquiries/{enquiryId}` — status and remarks together.
  Future<CoachingEnquiry> updateEnquiry(int id, CoachingEnquiryUpdate update);

  /// `PATCH /coaching-enquiries/{enquiryId}/assign-coach`
  Future<CoachingEnquiry> assignCoach({required int id, required int coachId});

  /// `PATCH /coaching-enquiries/{enquiryId}/status`
  Future<CoachingEnquiry> updateStatus({
    required int id,
    required CoachingEnquiryStatus status,
  });

  /// `DELETE /coaching-enquiries/{enquiryId}`
  Future<void> deleteEnquiry(int id);

  /// `GET /coaching-enquiries/stats`
  Future<CoachingEnquiryStats> getStats();

  /// Coaches for the assign dialog, from `GET /coaches`.
  Future<List<Coach>> fetchCoaches({bool refresh, int? sportId});

  /// Sports for the create form, from `GET /sports`.
  Future<List<Sport>> fetchSports({bool refresh});

  /// Venues for the create form, from `GET /sports-complexes`.
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh});
}
