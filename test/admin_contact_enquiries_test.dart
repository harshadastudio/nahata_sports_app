import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nahata_app/core/api/api_role.dart';
import 'package:nahata_app/core/api/role_api_map.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/features/admin/data/models/contact_inquiry_model.dart';
import 'package:nahata_app/features/admin/data/repositories/contact_enquiry_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/contact_inquiry.dart';
import 'package:nahata_app/features/admin/domain/repositories/contact_enquiry_repository.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_destination.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_module.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_shell_config.dart';
import 'package:nahata_app/features/admin/presentation/state/contact_enquiries_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/models/profile_model.dart';

/// `GET /contact-us/admin?page=1&limit=10`, verbatim.
Map<String, dynamic> _payload() => <String, dynamic>{
  'success': true,
  'data': {
    'inquiries': [
      {
        'id': 'df57972a-c0f6-458d-b7e0-e728e6c944fb',
        'fullName': 'Shiphan',
        'email': 'shiphan.anantkamalsoftwarelab@gmail.com',
        'subject': 'Test Subject',
        'message': 'Test Sinhagad',
        'status': 'read',
        'referenceNumber': 'NS-CON-2026-0005',
        'sportComplexId': 1,
        'ipAddress': '::1',
        'userAgent': 'Mozilla/5.0',
        'createdAt': '2026-07-08T09:45:32.128Z',
        'updatedAt': '2026-07-08T09:45:41.862Z',
        'deletedAt': null,
        'sportComplex': {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'},
      },
    ],
    'pagination': {'total': 1, 'page': 1, 'limit': 10, 'totalPages': 1},
    'statusCounts': {'new': 0, 'read': 1, 'replied': 0, 'total': 1},
  },
};

Map<String, dynamic> _user({
  required String role,
  int? complexId,
  Map<String, dynamic>? permissions,
}) => <String, dynamic>{
  'id': role == 'ADMIN' ? 1 : 503,
  'name': 'Test $role',
  'email': 'test@nahatasports.com',
  'role': role,
  'sportComplexId': complexId,
  'sportComplex': complexId == null
      ? null
      : {'id': complexId, 'name': 'Sinhagad Road', 'city': 'Pune'},
  if (permissions != null) 'permissions': permissions,
};

void _signIn(Map<String, dynamic> user) =>
    PermissionService.instance.sync(ProfileModel.fromJson(user));

/// A matrix that grants everything *except* contact enquiries, which it never
/// mentions — the shape every captured login payload actually has today.
Map<String, dynamic> _matrixWithoutContact() => <String, dynamic>{
  for (final module in const [
    'dashboard',
    'users',
    'sports',
    'sportsComplex',
    'coaches',
    'batches',
    'courts',
    'bookings',
    'memberships',
    'coupons',
    'payments',
    'reports',
    'students',
    'settings',
  ])
    module: {'view': true, 'create': true, 'edit': true, 'delete': true},
};

void main() {
  tearDown(PermissionService.instance.clear);

  group('The confirmed endpoint', () {
    test('is /contact-us/admin?page=1&limit=10 for both roles', () {
      for (final role in const [ApiRole.admin, ApiRole.complexAdmin]) {
        final route = RoleApiMap.require(
          ApiModule.contactEnquiries,
          role: role,
        );
        expect(route.method, 'GET');
        expect(route.path, '/contact-us/admin');
        expect(route.query['page'], 1);
        expect(route.query['limit'], 10);
      }
    });

    test('is ONE route — no /contact-us/complex-admin is invented', () {
      final admin = RoleApiMap.require(
        ApiModule.contactEnquiries,
        role: ApiRole.admin,
      );
      final complexAdmin = RoleApiMap.require(
        ApiModule.contactEnquiries,
        role: ApiRole.complexAdmin,
      );

      expect(admin.path, complexAdmin.path);
      expect(complexAdmin.path, isNot(contains('complex-admin')));
      // The venue comes from the JWT, so the URL must not carry it.
      expect(complexAdmin.scopeFromJwt, isTrue);
      expect(complexAdmin.query.containsKey('sportComplexId'), isFalse);
    });

    test('the trace names the module from the URL', () {
      expect(
        RoleApiMap.moduleForPath('/contact-us/admin'),
        ApiModule.contactEnquiries,
      );
      expect(
        RoleApiMap.moduleForPath('/api/contact-us/admin'),
        ApiModule.contactEnquiries,
      );
    });
  });

  group('ContactInquiryMapper', () {
    test('reads the captured payload whole', () {
      final result = ContactInquiryMapper.pageFrom(_payload());

      expect(result.items, hasLength(1));
      final row = result.items.single;

      expect(row.id, 'df57972a-c0f6-458d-b7e0-e728e6c944fb');
      expect(row.fullName, 'Shiphan');
      expect(row.email, 'shiphan.anantkamalsoftwarelab@gmail.com');
      expect(row.subject, 'Test Subject');
      expect(row.message, 'Test Sinhagad');
      expect(row.statusRaw, 'read');
      expect(row.status, ContactInquiryStatus.read);
      expect(row.referenceNumber, 'NS-CON-2026-0005');
      expect(row.sportComplexId, 1);
      expect(row.ipAddress, '::1');
      expect(row.userAgent, 'Mozilla/5.0');
      expect(row.createdAt?.toUtc().year, 2026);
      expect(row.updatedAt?.toUtc().month, 7);
      expect(row.deletedAt, isNull);
      expect(row.isDeleted, isFalse);
    });

    test('the id stays a string — it is a UUID, not a number', () {
      final row = ContactInquiryMapper.pageFrom(_payload()).items.single;
      expect(row.id, isA<String>());
      expect(int.tryParse(row.id), isNull);
    });

    test('reads the nested sport complex', () {
      final row = ContactInquiryMapper.pageFrom(_payload()).items.single;

      expect(row.sportComplex?.id, 1);
      expect(row.sportComplexName, 'Sinhagad Road');
      expect(row.sportComplex?.city, 'Pune');
      expect(row.sportComplexLabel, 'Sinhagad Road, Pune');
      expect(row.effectiveComplexId, 1);
    });

    test('reads the pagination block', () {
      final page = ContactInquiryMapper.pageFrom(_payload()).page;

      expect(page.total, 1);
      expect(page.page, 1);
      expect(page.limit, 10);
      expect(page.totalPages, 1);
      expect(page.hasNext, isFalse);
      expect(page.hasPrevious, isFalse);
    });

    test('reads statusCounts, including the reserved word `new`', () {
      final counts = ContactInquiryMapper.pageFrom(_payload()).counts;

      expect(counts.isNew, 0);
      expect(counts.read, 1);
      expect(counts.replied, 0);
      expect(counts.total, 1);
      expect(counts.effectiveTotal, 1);
      expect(counts.countOf(ContactInquiryStatus.read), 1);
      expect(counts.shareOf(ContactInquiryStatus.read), 1.0);
    });

    test('falls back to the requested page when pagination is absent', () {
      final result = ContactInquiryMapper.pageFrom(
        {
          'success': true,
          'data': {'inquiries': <dynamic>[]},
        },
        fallbackPage: 3,
        fallbackLimit: 25,
      );

      expect(result.page.page, 3);
      expect(result.page.limit, 25);
      expect(result.counts.effectiveTotal, 0);
    });

    test('a row with no id is dropped rather than given a made-up one', () {
      final result = ContactInquiryMapper.pageFrom({
        'data': {
          'inquiries': [
            {'fullName': 'No id'},
            {'id': 'abc', 'fullName': 'Has id'},
          ],
        },
      });

      expect(result.items, hasLength(1));
      expect(result.items.single.id, 'abc');
    });

    test('an unknown status keeps its own text', () {
      final row = ContactInquiryMapper.pageFrom({
        'data': {
          'inquiries': [
            {'id': 'x', 'fullName': 'A', 'status': 'escalated'},
          ],
        },
      }).items.single;

      expect(row.status, isNull);
      expect(row.statusLabel, 'Escalated');
    });

    test('effectiveTotal adds the states up when `total` is missing', () {
      final counts = ContactInquiryMapper.countsFrom({
        'new': 2,
        'read': 3,
        'replied': 1,
      });
      expect(counts.total, 0);
      expect(counts.effectiveTotal, 6);
    });
  });

  group('ContactInquiry', () {
    ContactInquiry rowWith({String? message, String fullName = 'Shiphan'}) =>
        ContactInquiry(id: 'x', fullName: fullName, message: message);

    test('the preview collapses newlines and truncates', () {
      final row = rowWith(message: 'Line one\n\n   Line two\tand three');
      expect(row.preview(), 'Line one Line two and three');

      final long = rowWith(message: 'a' * 200);
      expect(long.preview(max: 20).length, lessThanOrEqualTo(21));
      expect(long.preview(max: 20), endsWith('…'));
    });

    test('displayName never comes back blank', () {
      expect(rowWith(fullName: '   ').displayName, 'Unnamed enquiry');
      expect(
        const ContactInquiry(
          id: 'x',
          fullName: '',
          email: 'a@b.com',
        ).displayName,
        'a@b.com',
      );
    });

    test('a missing subject reads as "No subject", not as blank', () {
      expect(rowWith().subjectLabel, 'No subject');
    });
  });

  group('ContactEnquiryRepositoryImpl', () {
    test('calls the confirmed URL with page and limit', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode(_payload()), 200);
        }),
      );

      await ContactEnquiryRepositoryImpl().fetchEnquiries(page: 2, limit: 10);

      expect(captured.path, endsWith('/contact-us/admin'));
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '10');
    });

    test('sends no status or search parameter — neither is confirmed', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode(_payload()), 200);
        }),
      );

      await ContactEnquiryRepositoryImpl().fetchEnquiries();

      expect(captured.queryParameters.keys, unorderedEquals(['page', 'limit']));
    });

    test('a complex admin does not send sportComplexId', () async {
      late Uri captured;
      _signIn(_user(role: 'COMPLEX_ADMIN', complexId: 1));

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode(_payload()), 200);
        }),
      );

      await ContactEnquiryRepositoryImpl().fetchEnquiries();

      expect(captured.queryParameters.containsKey('sportComplexId'), isFalse);
    });

    test('a 403 surfaces as a permission error, not as empty rows', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient(
          (request) async => http.Response(
            jsonEncode({'success': false, 'message': 'Access denied'}),
            403,
          ),
        ),
      );

      await expectLater(
        ContactEnquiryRepositoryImpl().fetchEnquiries(),
        throwsA(
          predicate(
            (error) => error.toString().contains('Access denied'),
            'carries the server message',
          ),
        ),
      );
    });
  });

  group('ContactEnquiriesController', () {
    test('loads a page and keeps the payload counts', () async {
      final controller = ContactEnquiriesController(_FakeRepository());
      await controller.load();

      expect(controller.state, ViewState.ready);
      expect(controller.enquiries, hasLength(1));
      // Straight from `statusCounts` — never counted off the rows on screen.
      expect(controller.counts.read, 1);
      expect(controller.counts.effectiveTotal, 1);

      controller.dispose();
    });

    test('paging asks the server for the next page', () async {
      final repository = _FakeRepository();
      final controller = ContactEnquiriesController(repository);

      await controller.load();
      await controller.goToPage(2);

      expect(repository.requestedPages, [1, 2]);
      controller.dispose();
    });

    test('the default page size is the confirmed 10', () {
      final controller = ContactEnquiriesController(_FakeRepository());
      expect(controller.limit, 10);
      expect(ContactEnquiriesController.defaultLimit, 10);
      controller.dispose();
    });

    test('the status filter narrows the page and says so', () async {
      final controller = ContactEnquiriesController(
        _FakeRepository(
          rows: [
            _row('a', ContactInquiryStatus.isNew),
            _row('b', ContactInquiryStatus.read),
            _row('c', ContactInquiryStatus.read),
          ],
        ),
      );
      await controller.load();

      controller.setStatusFilter(ContactInquiryStatus.read);
      expect(controller.enquiries.map((e) => e.id), ['b', 'c']);
      expect(controller.filterIsPageScoped, isTrue);
      expect(controller.loadedCount, 3);

      // Tapping the same card again clears it.
      controller.toggleStatusFilter(ContactInquiryStatus.read);
      expect(controller.statusFilter, isNull);
      expect(controller.enquiries, hasLength(3));

      controller.dispose();
    });

    test('search matches across the fields a desk would look in', () async {
      final controller = ContactEnquiriesController(_FakeRepository());
      await controller.load();

      for (final term in const [
        'shiphan',
        'NS-CON-2026-0005',
        'Test Subject',
        'sinhagad',
      ]) {
        controller.onSearchChanged(term);
        expect(controller.enquiries, hasLength(1), reason: term);
      }

      controller.onSearchChanged('nothing here');
      expect(controller.enquiries, isEmpty);
      expect(controller.hasFilters, isTrue);

      controller.clearFilters();
      expect(controller.enquiries, hasLength(1));

      controller.dispose();
    });

    test('a failure surfaces the server message and keeps the page', () async {
      final controller = ContactEnquiriesController(
        _FakeRepository(failWith: 'Server is down'),
      );
      await controller.load();

      expect(controller.state, ViewState.failed);
      expect(controller.error, 'Server is down');

      controller.dispose();
    });

    test('a superseded response never overwrites a newer one', () async {
      final repository = _FakeRepository();
      final controller = ContactEnquiriesController(repository);

      final slow = controller.load(page: 1);
      final fast = controller.load(page: 2);
      await Future.wait([slow, fast]);

      expect(controller.page.page, 2);
      controller.dispose();
    });
  });

  group('Permissions and the sidebar', () {
    test('the module appears in both consoles', () {
      expect(
        AdminShellConfig.admin.sections
            .expand((section) => section.destinations)
            .contains(AdminDestination.contactEnquiries),
        isTrue,
      );

      _signIn(
        _user(
          role: 'COMPLEX_ADMIN',
          complexId: 1,
          permissions: _matrixWithoutContact(),
        ),
      );

      expect(
        AdminShellConfig.complexAdmin().sections
            .expand((section) => section.destinations)
            .contains(AdminDestination.contactEnquiries),
        isTrue,
      );
    });

    test('an explicit false hides it', () {
      _signIn(
        _user(
          role: 'COMPLEX_ADMIN',
          complexId: 1,
          permissions: {
            ..._matrixWithoutContact(),
            'contactEnquiries': {'view': false},
          },
        ),
      );

      expect(AdminAccess.allows(AdminDestination.contactEnquiries), isFalse);
      expect(
        AdminShellConfig.complexAdmin().allows(
          AdminDestination.contactEnquiries,
        ),
        isFalse,
      );
    });

    test('an explicit true shows it', () {
      _signIn(
        _user(
          role: 'COMPLEX_ADMIN',
          complexId: 1,
          permissions: {
            ..._matrixWithoutContact(),
            'contactEnquiries': {'view': true, 'edit': false},
          },
        ),
      );

      expect(AdminAccess.canView(AdminModules.contactEnquiries), isTrue);
      expect(AdminAccess.canEdit(AdminModules.contactEnquiries), isFalse);
    });

    test('whichever spelling the backend sends is the one that counts', () {
      for (final key in const [
        'contactEnquiries',
        'contactInquiries',
        'contactUs',
        'contact_us',
        'contacts',
      ]) {
        _signIn(
          _user(
            role: 'ADMIN',
            permissions: {
              ..._matrixWithoutContact(),
              key: {'view': false},
            },
          ),
        );

        expect(
          AdminAccess.canView(AdminModules.contactEnquiries),
          isFalse,
          reason: '$key: {view: false} must hide the module',
        );
        PermissionService.instance.clear();
      }
    });

    test(
      'a matrix that never mentions the module leaves it visible',
      () {
        // No captured login payload carries a key for Contact Enquiries.
        // Silence means "this API says nothing", not `view: false` — treating
        // it as denial would hide the module from a full ADMIN.
        _signIn(_user(role: 'ADMIN', permissions: _matrixWithoutContact()));

        expect(AdminAccess.canView(AdminModules.contactEnquiries), isTrue);
        expect(AdminAccess.allows(AdminDestination.contactEnquiries), isTrue);

        // The rule is scoped to this module only: an unmentioned module that
        // *has* been observed in real payloads is still denied.
        expect(AdminAccess.canView('somethingInvented'), isFalse);
      },
    );

    test('a module the payload does grant is unaffected', () {
      _signIn(
        _user(
          role: 'COMPLEX_ADMIN',
          complexId: 1,
          permissions: {
            'coaches': {'view': true, 'delete': false},
            'sports': {'view': false},
          },
        ),
      );

      expect(AdminAccess.canView(AdminModules.coaches), isTrue);
      expect(AdminAccess.canDelete(AdminModules.coaches), isFalse);
      expect(AdminAccess.canView(AdminModules.sports), isFalse);
    });
  });
}

// -----------------------------------------------------------------------------

ContactInquiry _row(String id, ContactInquiryStatus status) => ContactInquiry(
  id: id,
  fullName: 'Sender $id',
  statusRaw: status.slug,
);

class _FakeRepository implements ContactEnquiryRepository {
  _FakeRepository({this.rows, this.failWith});

  final List<ContactInquiry>? rows;
  final String? failWith;
  final List<int> requestedPages = <int>[];

  @override
  Future<ContactInquiryPage> fetchEnquiries({
    int page = 1,
    int limit = 10,
  }) async {
    requestedPages.add(page);
    if (failWith != null) throw ServerException(failWith!);

    final result = ContactInquiryMapper.pageFrom(
      _payload(),
      fallbackPage: page,
      fallbackLimit: limit,
    );

    if (rows == null) {
      return ContactInquiryPage(
        page: result.page.copyWith(page: page),
        counts: result.counts,
      );
    }

    return ContactInquiryPage(
      page: result.page.copyWith(items: rows, page: page),
      counts: result.counts,
    );
  }
}