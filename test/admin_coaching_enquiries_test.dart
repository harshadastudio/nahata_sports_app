import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/coaching_enquiry_model.dart';
import 'package:nahata_app/features/admin/data/repositories/coaching_enquiry_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/coach.dart';
import 'package:nahata_app/features/admin/domain/entities/coaching_enquiry.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/coaching_enquiry_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/coaching_enquiries_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return _secureStore[key];
          case 'write':
            _secureStore[key!] = args['value'] as String;
            return null;
          case 'delete':
            _secureStore.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.from(_secureStore);
          default:
            return null;
        }
      });
}

CoachingEnquiry _enquiry({
  int id = 1,
  String name = 'Rahul Deshpande',
  String status = 'New',
  int? coachId,
  String? coachName,
  String? remarks,
}) {
  return CoachingEnquiry(
    id: id,
    name: name,
    phone: '9876543210',
    email: 'rahul@example.com',
    message: 'Looking for evening badminton coaching',
    statusRaw: status,
    remarks: remarks,
    sportId: 7,
    sportName: 'Badminton',
    sportComplexId: 2,
    sportComplexName: 'Kothrud Arena',
    assignedCoachId: coachId,
    assignedCoachName: coachName,
    createdAt: DateTime(2026, 8, 1),
  );
}

CoachingEnquiryDraft _draft({
  String name = 'Rahul Deshpande',
  String phone = '9876543210',
  String email = 'rahul@example.com',
  int? sportId = 7,
  int? complexId = 2,
  String message = 'Looking for evening badminton coaching',
}) {
  return CoachingEnquiryDraft(
    name: name,
    phone: phone,
    email: email,
    sportId: sportId,
    sportComplexId: complexId,
    message: message,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  // ---------------------------------------------------------------------------
  group('CoachingEnquiryStatus', () {
    test('the five documented values are sent verbatim', () {
      expect(CoachingEnquiryStatus.values.map((status) => status.slug), [
        'New',
        'Contacted',
        'Interested',
        'Joined',
        'Closed',
      ]);
    });

    test('the spellings other parts of this backend use are tolerated', () {
      expect(
        CoachingEnquiryStatus.tryParse('pending'),
        CoachingEnquiryStatus.isNew,
      );
      // The coach's own enquiry list calls a joined prospect "Converted".
      expect(
        CoachingEnquiryStatus.tryParse('Converted'),
        CoachingEnquiryStatus.joined,
      );
      expect(
        CoachingEnquiryStatus.tryParse('CANCELLED'),
        CoachingEnquiryStatus.closed,
      );
    });

    test('an unrecognised status is shown verbatim, never coerced', () {
      expect(CoachingEnquiryStatus.tryParse('Escalated'), isNull);
      expect(CoachingEnquiryStatus.labelFor('escalated'), 'Escalated');
      expect(CoachingEnquiryStatus.labelFor(null), '');
    });

    test('joined and closed are the settled outcomes', () {
      expect(CoachingEnquiryStatus.joined.isSettled, isTrue);
      expect(CoachingEnquiryStatus.closed.isSettled, isTrue);
      expect(CoachingEnquiryStatus.contacted.isSettled, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachingEnquiry', () {
    test('the display name falls back through email to the id', () {
      expect(_enquiry().displayName, 'Rahul Deshpande');
      expect(
        const CoachingEnquiry(id: 4, email: 'x@y.com').displayName,
        'x@y.com',
      );
      expect(const CoachingEnquiry(id: 4).displayName, 'Enquiry 4');
    });

    test('the interest line survives a missing half', () {
      expect(_enquiry().interestLabel, 'Badminton at Kothrud Arena');
      expect(
        const CoachingEnquiry(id: 1, sportName: 'Tennis').interestLabel,
        'Tennis',
      );
      expect(const CoachingEnquiry(id: 1).interestLabel, '');
    });

    test('assignment and remarks are read as presence, not as text', () {
      expect(_enquiry().isAssigned, isFalse);
      expect(_enquiry(coachId: 9).isAssigned, isTrue);
      expect(_enquiry(remarks: '   ').hasRemarks, isFalse);
      expect(_enquiry(remarks: 'Called back').hasRemarks, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachingEnquiryUpdate', () {
    test('only what was touched is sent', () {
      expect(
        const CoachingEnquiryUpdate(
          status: CoachingEnquiryStatus.contacted,
        ).toJson(),
        {'status': 'Contacted'},
      );
      expect(const CoachingEnquiryUpdate(remarks: ' Called back ').toJson(), {
        'remarks': 'Called back',
      });
    });

    test('an emptied remarks box is a real edit, not a skipped field', () {
      // A `put`-style helper that drops empty strings would silently discard
      // the desk clearing a note.
      expect(const CoachingEnquiryUpdate(remarks: '').toJson(), {
        'remarks': '',
      });
    });

    test('an untouched update is empty', () {
      expect(const CoachingEnquiryUpdate().isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachingEnquiryStats', () {
    test('the total is derived when the API sends none', () {
      const stats = CoachingEnquiryStats(
        newCount: 4,
        contacted: 3,
        interested: 2,
        joined: 1,
        closed: 5,
      );
      expect(stats.effectiveTotal, 15);
      expect(stats.countOf(CoachingEnquiryStatus.interested), 2);
    });

    test('a sent total wins over the sum', () {
      const stats = CoachingEnquiryStats(total: 20, newCount: 4);
      expect(stats.effectiveTotal, 20);
    });

    test('shares are null when there is nothing to take a share of', () {
      expect(
        const CoachingEnquiryStats().shareOf(CoachingEnquiryStatus.isNew),
        isNull,
      );
      const stats = CoachingEnquiryStats(total: 10, newCount: 5);
      expect(stats.shareOf(CoachingEnquiryStatus.isNew), 0.5);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachingEnquiryMapper', () {
    test('reads the documented list envelope and its counters', () {
      final page = CoachingEnquiryMapper.pageFrom(
        {
          'success': true,
          'data': [
            {
              'id': 12,
              'name': 'Rahul Deshpande',
              'phone': '9876543210',
              'email': 'rahul@example.com',
              'status': 'New',
              'sport': {'id': 7, 'name': 'Badminton'},
              'sportComplex': {'id': 2, 'name': 'Kothrud Arena'},
              'createdAt': '2026-08-01T09:30:00Z',
            },
            {'id': 13, 'name': 'Sana Shaikh'},
          ],
          'total': 47,
          'page': 2,
          'limit': 20,
        },
        fallbackPage: 1,
        fallbackLimit: 20,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 47);
      expect(page.page, 2);

      final enquiry = page.items.first;
      expect(enquiry.sportId, 7);
      expect(enquiry.sportName, 'Badminton');
      expect(enquiry.sportComplexName, 'Kothrud Arena');
      expect(enquiry.status, CoachingEnquiryStatus.isNew);
    });

    test('the embedded user never becomes the enquiry itself', () {
      final enquiry = CoachingEnquiryMapper.fromJson({
        'id': 12,
        'user': {'id': 585, 'name': 'Rahul Deshpande', 'email': 'r@x.com'},
        'coach': {'id': 9, 'name': 'Coach Anil'},
      });

      // Both ids belong to other records — inheriting either would make every
      // `/{id}` call address the wrong thing.
      expect(enquiry.id, 12);
      expect(enquiry.name, 'Rahul Deshpande');
      expect(enquiry.email, 'r@x.com');
      expect(enquiry.assignedCoachId, 9);
      expect(enquiry.assignedCoachName, 'Coach Anil');
    });

    test('snake_case rows read the same as camelCase ones', () {
      final enquiry = CoachingEnquiryMapper.fromJson({
        'id': 12,
        'customer_name': 'Rahul',
        'phone_number': '9876543210',
        'sport_id': 7,
        'sport_complex_id': 2,
        'assigned_coach_id': 9,
        'admin_remarks': 'Called back',
        'created_at': '2026-08-01',
        'updated_at': '2026-08-04',
      });

      expect(enquiry.name, 'Rahul');
      expect(enquiry.phone, '9876543210');
      expect(enquiry.sportId, 7);
      expect(enquiry.sportComplexId, 2);
      expect(enquiry.assignedCoachId, 9);
      expect(enquiry.remarks, 'Called back');
      expect(enquiry.updatedAt, DateTime.parse('2026-08-04'));
    });

    test('rows with no id are dropped rather than shown inert', () {
      final rows = CoachingEnquiryMapper.listFrom({
        'data': [
          {'name': 'Ghost'},
          {'id': 3, 'name': 'Real'},
        ],
      });
      expect(rows, hasLength(1));
      expect(rows.single.name, 'Real');
    });

    test('stats are read flat or from a byStatus block', () {
      final flat = CoachingEnquiryMapper.statsFrom({
        'success': true,
        'data': {
          'total': 47,
          'new': 12,
          'contacted': 9,
          'interested': 8,
          'joined': 11,
          'closed': 7,
        },
      });
      expect(flat.total, 47);
      expect(flat.newCount, 12);
      expect(flat.closed, 7);

      final grouped = CoachingEnquiryMapper.statsFrom({
        'success': true,
        'data': {
          'totalEnquiries': 47,
          'byStatus': {'New': 12, 'Joined': 11},
        },
      });
      expect(grouped.total, 47);
      expect(grouped.newCount, 12);
      expect(grouped.joined, 11);
    });

    test('a bare envelope carries no enquiry', () {
      expect(
        CoachingEnquiryMapper.maybeFromBody({
          'success': false,
          'message': 'Not found',
        }),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachingEnquiryRepositoryImpl — the wire', () {
    test('the list route sends paging, and filters only when set', () async {
      final calls = <Uri>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add(request.url);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = CoachingEnquiryRepositoryImpl();
      await repository.getEnquiries(page: 2, limit: 50);
      await repository.getEnquiries(
        search: 'rahul',
        status: CoachingEnquiryStatus.contacted,
      );

      expect(calls[0].path, endsWith('/coaching-enquiries'));
      expect(calls[0].queryParameters['page'], '2');
      expect(calls[0].queryParameters['limit'], '50');
      expect(calls[0].queryParameters.containsKey('search'), isFalse);
      expect(calls[0].queryParameters.containsKey('status'), isFalse);
      expect(calls[1].queryParameters['search'], 'rahul');
      expect(calls[1].queryParameters['status'], 'Contacted');
    });

    test('every write route uses its documented method and path', () async {
      final calls = <String>[];
      final bodies = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          bodies.add(request.body);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 7, 'name': 'Rahul'},
            }),
            200,
          );
        }),
      );

      final repository = CoachingEnquiryRepositoryImpl();
      await repository.getEnquiry(7);
      await repository.updateEnquiry(
        7,
        const CoachingEnquiryUpdate(
          status: CoachingEnquiryStatus.contacted,
          remarks: 'Called back',
        ),
      );
      await repository.assignCoach(id: 7, coachId: 9);
      await repository.updateStatus(
        id: 7,
        status: CoachingEnquiryStatus.joined,
      );
      await repository.deleteEnquiry(7);
      await repository.getStats();

      expect(calls[0], 'GET /api/coaching-enquiries/7');
      expect(calls[1], 'PUT /api/coaching-enquiries/7');
      expect(calls[2], 'PATCH /api/coaching-enquiries/7/assign-coach');
      expect(calls[3], 'PATCH /api/coaching-enquiries/7/status');
      expect(calls[4], 'DELETE /api/coaching-enquiries/7');
      // `/stats` is a fixed segment, not an id.
      expect(calls[5], 'GET /api/coaching-enquiries/stats');

      expect(jsonDecode(bodies[1]), {
        'status': 'Contacted',
        'remarks': 'Called back',
      });
      expect(jsonDecode(bodies[2]), {'coachId': 9});
      expect(jsonDecode(bodies[3]), {'status': 'Joined'});
    });

    test('create posts the documented body', () async {
      late Map<String, dynamic> body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 12, 'name': 'Rahul Deshpande'},
            }),
            201,
          );
        }),
      );

      final created = await CoachingEnquiryRepositoryImpl().createEnquiry(
        _draft(phone: '98765 43210'),
      );

      expect(body['name'], 'Rahul Deshpande');
      // Formatting typed into the field never reaches the API.
      expect(body['phone'], '9876543210');
      expect(body['email'], 'rahul@example.com');
      expect(body['sportId'], 7);
      expect(body['sportComplexId'], 2);
      expect(body['message'], isNotEmpty);
      expect(created.id, 12);
    });

    test(
      'a body the server could only reject never leaves the device',
      () async {
        var called = false;
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            called = true;
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        final repository = CoachingEnquiryRepositoryImpl();

        await expectLater(
          repository.createEnquiry(_draft(name: ' ')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createEnquiry(_draft(phone: '98765')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createEnquiry(_draft(email: 'not-an-email')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createEnquiry(_draft(sportId: null)),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createEnquiry(_draft(complexId: null)),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createEnquiry(_draft(message: '')),
          throwsA(isA<ValidationException>()),
        );

        expect(called, isFalse);
      },
    );

    test('an empty update is refused before the round trip', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        CoachingEnquiryRepositoryImpl().updateEnquiry(
          7,
          const CoachingEnquiryUpdate(),
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test(
      'a write the server did not echo still resolves to the record',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            // The three write routes are documented without a response body.
            return http.Response(
              jsonEncode({'success': true, 'message': 'Updated'}),
              200,
            );
          }),
        );

        final updated = await CoachingEnquiryRepositoryImpl().updateStatus(
          id: 7,
          status: CoachingEnquiryStatus.joined,
        );

        expect(updated.id, 7);
      },
    );

    test('a 404 on the detail route reaches the caller typed', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'success': false, 'message': 'Enquiry not found'}),
            404,
          );
        }),
      );

      await expectLater(
        CoachingEnquiryRepositoryImpl().getEnquiry(99),
        throwsA(
          isA<NotFoundException>().having(
            (error) => error.message,
            'message',
            'Enquiry not found',
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachingEnquiriesController', () {
    test('paging replaces the rows, scrolling appends them', () async {
      final repository = _FakeRepository(total: 5, pageSize: 2);
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      expect(controller.enquiries, hasLength(2));
      expect(controller.state, ViewState.ready);

      await controller.loadMore();
      expect(controller.enquiries, hasLength(4));
      expect(controller.page.page, 2);

      await controller.load(page: 1);
      expect(controller.enquiries, hasLength(2));

      controller.dispose();
    });

    test('an overlapping page never shows the same enquiry twice', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2, overlap: true);
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      await controller.loadMore();

      final ids = controller.enquiries.map((enquiry) => enquiry.id).toList();
      expect(ids.toSet(), hasLength(ids.length));

      controller.dispose();
    });

    test('a failed load keeps the rows already on screen', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2);
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      repository.failNextList = true;
      await controller.load(page: 2);

      expect(controller.state, ViewState.failed);
      expect(controller.error, isNotNull);
      expect(controller.enquiries, hasLength(2));

      controller.dispose();
    });

    test('a status change moves the badge before the server answers', () async {
      final repository = _FakeRepository(
        total: 2,
        pageSize: 2,
        slowWrites: true,
      );
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      expect(controller.enquiries.first.status, CoachingEnquiryStatus.isNew);

      final pending = controller.changeStatus(
        id: controller.enquiries.first.id,
        status: CoachingEnquiryStatus.contacted,
      );

      // Optimistic: the row has already moved while the call is in flight.
      expect(
        controller.enquiries.first.status,
        CoachingEnquiryStatus.contacted,
      );

      repository.releaseWrites();
      await pending;
      expect(
        controller.enquiries.first.status,
        CoachingEnquiryStatus.contacted,
      );

      controller.dispose();
    });

    test('a refused status change puts the badge back', () async {
      final repository = _FakeRepository(total: 2, pageSize: 2);
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      repository.failNextWrite = true;

      await expectLater(
        controller.changeStatus(
          id: controller.enquiries.first.id,
          status: CoachingEnquiryStatus.joined,
        ),
        throwsA(isA<ApiException>()),
      );

      expect(controller.enquiries.first.status, CoachingEnquiryStatus.isNew);

      controller.dispose();
    });

    test('deleting removes the row immediately', () async {
      final repository = _FakeRepository(
        total: 3,
        pageSize: 3,
        slowWrites: true,
      );
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      final id = controller.enquiries.first.id;

      final pending = controller.delete(id);
      expect(controller.enquiries.any((e) => e.id == id), isFalse);

      repository.releaseWrites();
      await pending;
      expect(repository.deleted, [id]);

      controller.dispose();
    });

    test('a refused delete puts the row back', () async {
      final repository = _FakeRepository(total: 3, pageSize: 3);
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      final id = controller.enquiries.first.id;
      repository.failNextWrite = true;

      await expectLater(controller.delete(id), throwsA(isA<ApiException>()));
      expect(controller.enquiries.any((e) => e.id == id), isTrue);

      controller.dispose();
    });

    test('assigning fills the coach in from the one that was picked', () async {
      // The assign route is documented without a response body, so the name
      // has to come from the picked coach or the row would blank.
      final repository = _FakeRepository(
        total: 1,
        pageSize: 1,
        echoWrites: false,
      );
      final controller = CoachingEnquiriesController(repository);

      await controller.load();
      final updated = await controller.assignCoach(
        id: controller.enquiries.first.id,
        coach: const Coach(id: 9, name: 'Coach Anil'),
      );

      expect(updated.assignedCoachId, 9);
      expect(updated.assignedCoachName, 'Coach Anil');

      controller.dispose();
    });

    test(
      'a stat card filters the queue, and tapping it again clears it',
      () async {
        final repository = _FakeRepository(total: 4, pageSize: 4);
        final controller = CoachingEnquiriesController(repository);

        await controller.load();
        controller.setStatusFilter(CoachingEnquiryStatus.contacted);
        expect(controller.statusFilter, CoachingEnquiryStatus.contacted);
        expect(controller.hasFilters, isTrue);

        controller.setStatusFilter(CoachingEnquiryStatus.contacted);
        expect(controller.statusFilter, isNull);

        controller.dispose();
      },
    );

    test('the stats are read once and reused until refreshed', () async {
      final repository = _FakeRepository();
      final controller = CoachingEnquiriesController(repository);

      await controller.loadStats();
      await controller.loadStats();
      expect(repository.statsCalls, 1);

      await controller.loadStats(refresh: true);
      expect(repository.statsCalls, 2);
      expect(controller.stats.effectiveTotal, 15);

      controller.dispose();
    });

    test('creating refreshes the list and the counters', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2);
      final controller = CoachingEnquiriesController(repository);

      await controller.load(page: 2);
      await controller.create(_draft());

      expect(controller.page.page, 1);
      expect(repository.created, 1);

      controller.dispose();
    });
  });
}

/// A repository that answers from memory, so the controller can be exercised
/// without a socket.
class _FakeRepository implements CoachingEnquiryRepository {
  _FakeRepository({
    this.total = 0,
    this.pageSize = 20,
    this.overlap = false,
    this.slowWrites = false,
    this.echoWrites = true,
  });

  final int total;
  final int pageSize;

  /// Repeats the last row of the previous page, the way a live list does when
  /// an enquiry is logged while the desk is scrolling.
  final bool overlap;

  /// Holds writes open so a test can observe the optimistic state.
  final bool slowWrites;

  /// When false, write routes answer with an id-only record — the documented
  /// shape for the three PATCH/PUT routes.
  final bool echoWrites;

  bool failNextList = false;
  bool failNextWrite = false;

  int listCalls = 0;
  int statsCalls = 0;
  int created = 0;
  final List<int> deleted = <int>[];

  Completer<void>? _gate;

  void releaseWrites() {
    _gate?.complete();
    _gate = null;
  }

  Future<void> _write() async {
    if (failNextWrite) {
      failNextWrite = false;
      throw const ServerException('Server is temporarily unavailable.');
    }
    if (!slowWrites) return;
    _gate = Completer<void>();
    await _gate!.future;
  }

  @override
  Future<Paged<CoachingEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    String? search,
    CoachingEnquiryStatus? status,
  }) async {
    if (failNextList) {
      failNextList = false;
      throw const ServerException('Server is temporarily unavailable.');
    }

    listCalls++;

    final start = (page - 1) * pageSize - (overlap && page > 1 ? 1 : 0);
    final items = <CoachingEnquiry>[];
    for (
      var index = start;
      index < start + pageSize && index < total;
      index++
    ) {
      items.add(_enquiry(id: index + 1, name: 'Prospect ${index + 1}'));
    }

    return Paged<CoachingEnquiry>(
      items: items,
      page: page,
      limit: pageSize,
      total: total,
      totalPages: (total / pageSize).ceil(),
    );
  }

  @override
  Future<CoachingEnquiry> getEnquiry(int id) async => _enquiry(id: id);

  @override
  Future<CoachingEnquiry> createEnquiry(CoachingEnquiryDraft draft) async {
    created++;
    return _enquiry(id: 99, name: draft.name);
  }

  @override
  Future<CoachingEnquiry> updateEnquiry(
    int id,
    CoachingEnquiryUpdate update,
  ) async {
    await _write();
    return echoWrites
        ? _enquiry(id: id, status: update.status?.slug ?? 'New')
        : CoachingEnquiry(id: id);
  }

  @override
  Future<CoachingEnquiry> assignCoach({
    required int id,
    required int coachId,
  }) async {
    await _write();
    return echoWrites
        ? _enquiry(id: id, coachId: coachId, coachName: 'Coach $coachId')
        : CoachingEnquiry(id: id);
  }

  @override
  Future<CoachingEnquiry> updateStatus({
    required int id,
    required CoachingEnquiryStatus status,
  }) async {
    await _write();
    return echoWrites
        ? _enquiry(id: id, status: status.slug)
        : CoachingEnquiry(id: id);
  }

  @override
  Future<void> deleteEnquiry(int id) async {
    await _write();
    deleted.add(id);
  }

  @override
  Future<CoachingEnquiryStats> getStats() async {
    statsCalls++;
    return const CoachingEnquiryStats(
      newCount: 4,
      contacted: 3,
      interested: 2,
      joined: 1,
      closed: 5,
    );
  }

  @override
  Future<List<Coach>> fetchCoaches({bool refresh = false, int? sportId}) async {
    return const [Coach(id: 9, name: 'Coach Anil')];
  }

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async {
    return const [Sport(id: 7, name: 'Badminton', sportComplexId: 2)];
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    return const [SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune')];
  }
}
