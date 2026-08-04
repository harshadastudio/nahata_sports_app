import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/models/batch_model.dart';

/// One batch exactly as `/batches?status=Active` returns it.
const String _batchListJson = '''
{
  "success": true,
  "message": "Batches retrieved successfully",
  "data": {
    "batches": [
      {
        "features": [],
        "id": 53,
        "name": "3 DAYS( Evening)",
        "sportId": 19,
        "coachId": 23,
        "sportComplexId": 1,
        "schedule": "7:00 PM to 8:00 PM",
        "days": "Monday,Tuesday,Wednesday,Thursday,Friday",
        "startDate": "2026-07-01",
        "endDate": "2026-07-31",
        "maxStudents": 25,
        "currentStudents": 1,
        "status": "Active",
        "fees": "2500.00",
        "description": null,
        "ageGroup": "5 To 50 Years",
        "duration": null,
        "startTime": null,
        "endTime": null,
        "image": null,
        "legacyProgramId": null,
        "createdAt": "2026-07-14T09:31:22.808Z",
        "updatedAt": "2026-07-17T04:27:16.918Z",
        "sport": {
          "id": 19,
          "name": "Badminton",
          "category": "Indoor",
          "image": "https://api.nahatasports.com/uploads/nahata-sports/sports/sports-1783573669024-335965277.png"
        },
        "coach": {
          "id": 23,
          "name": "Sudhanshu Medsikar",
          "email": "smedsikar@gmail.com",
          "phone": "7507069898"
        }
      },
      {
        "features": [],
        "id": 50,
        "name": "3 DAYS (Morning)   ",
        "sportId": 19,
        "coachId": 23,
        "sportComplexId": 1,
        "schedule": "8:00 AM to 9:00 AM",
        "days": "Monday,Tuesday,Wednesday,Thursday,Friday",
        "startDate": "2026-07-01",
        "endDate": "2026-07-31",
        "maxStudents": 25,
        "currentStudents": 0,
        "status": "Active",
        "fees": "2500.00",
        "ageGroup": "20 and Above",
        "sport": {"id": 19, "name": "Badminton", "category": "Indoor"},
        "coach": {"id": 23, "name": "Sudhanshu Medsikar"}
      }
    ],
    "currentPage": 1,
    "totalPages": 4,
    "totalItems": 32,
    "itemsPerPage": 10
  }
}
''';

const String _statsJson = '''
{
  "success": true,
  "data": {
    "batchId": 53,
    "batchName": "3 DAYS( Evening)",
    "sport": "Badminton",
    "coach": "Sudhanshu Medsikar",
    "maxStudents": 25,
    "currentStudents": 1,
    "enrolledStudents": 0,
    "availableSlots": 24,
    "occupancyPercentage": 4,
    "status": "Active",
    "fees": "2500.00",
    "startDate": "2026-07-01",
    "endDate": "2026-07-31"
  }
}
''';

/// The `/batches/sport/{id}` variant, which nests `ground` on the coach.
const String _bySportCoach = '''
{"id": 23, "name": "Sudhanshu Medsikar", "ground": "Sinhagad Road"}
''';

BatchPage _page() {
  final decoded = jsonDecode(_batchListJson) as Map<String, dynamic>;
  return BatchPage.fromJson(decoded['data'] as Map<String, dynamic>);
}

void main() {
  group('BatchPage', () {
    test('parses pagination metadata', () {
      final page = _page();

      expect(page.batches, hasLength(2));
      expect(page.currentPage, 1);
      expect(page.totalPages, 4);
      expect(page.totalItems, 32);
      expect(page.itemsPerPage, 10);
      expect(page.hasMore, isTrue);
    });

    test('last page reports no more results', () {
      final page = BatchPage.fromJson(const {
        'batches': [],
        'currentPage': 4,
        'totalPages': 4,
      });
      expect(page.hasMore, isFalse);
    });

    test('an empty or malformed payload yields an empty page', () {
      expect(BatchPage.fromJson(const {}).batches, isEmpty);
      expect(BatchPage.fromJson(const {'batches': 'nope'}).batches, isEmpty);
    });
  });

  group('BatchModel', () {
    test('maps the documented fields', () {
      final batch = _page().batches.first;

      expect(batch.id, 53);
      expect(batch.sportId, 19);
      expect(batch.coachId, 23);
      expect(batch.sportComplexId, 1);
      expect(batch.schedule, '7:00 PM to 8:00 PM');
      expect(batch.startDate, '2026-07-01');
      expect(batch.endDate, '2026-07-31');
      expect(batch.maxStudents, 25);
      expect(batch.currentStudents, 1);
      expect(batch.status, 'Active');
      expect(batch.fees, '2500.00');
      expect(batch.ageGroup, '5 To 50 Years');
      expect(batch.description, isNull);
      expect(batch.duration, isNull);
      expect(batch.features, isEmpty);
      expect(batch.isActive, isTrue);
    });

    test('trims the padded batch names the API returns', () {
      expect(_page().batches[1].displayName, '3 DAYS (Morning)');
    });

    test('derives session start/end from the schedule string', () {
      final batch = _page().batches.first;

      // startTime/endTime are null in the payload — schedule is the only source.
      expect(batch.startTime, isNull);
      expect(batch.sessionStart, '7:00 PM');
      expect(batch.sessionEnd, '8:00 PM');
    });

    test('handles the "To" and dash spellings of the schedule separator', () {
      String start(String schedule) =>
          BatchModel.fromJson({'schedule': schedule}).sessionStart;
      String end(String schedule) =>
          BatchModel.fromJson({'schedule': schedule}).sessionEnd;

      expect(start('6:00 PM To 7:00 PM'), '6:00 PM');
      expect(end('6:00 PM To 7:00 PM'), '7:00 PM');
      expect(end('5:00 PM - 6:00 PM'), '6:00 PM');
    });

    test('prefers explicit startTime/endTime columns when present', () {
      final batch = BatchModel.fromJson(const {
        'schedule': '7:00 PM to 8:00 PM',
        'startTime': '19:15',
        'endTime': '20:15',
      });

      expect(batch.sessionStart, '19:15');
      expect(batch.sessionEnd, '20:15');
    });

    test('an unparseable schedule does not produce a bogus end time', () {
      final batch = BatchModel.fromJson(const {'schedule': 'Flexible'});
      expect(batch.sessionStart, 'Flexible');
      expect(batch.sessionEnd, '');
    });

    test('formats fees without trailing zeros', () {
      expect(_page().batches.first.feesLabel, '2500');
      expect(BatchModel.fromJson(const {'fees': '3000.00'}).feesLabel, '3000');
      expect(BatchModel.fromJson(const {'fees': '2500.50'}).feesLabel, '2500.50');
      expect(BatchModel.fromJson(const {}).feesLabel, '0');
    });

    test('formats the start month for the "Starting from" label', () {
      expect(_page().batches.first.startMonthLabel, 'July 2026');
      expect(BatchModel.fromJson(const {}).startMonthLabel, '');
    });

    test('formats the comma separated days for display', () {
      expect(
        _page().batches.first.daysLabel,
        'Monday, Tuesday, Wednesday, Thursday, Friday',
      );
    });

    test('computes remaining capacity', () {
      final batch = _page().batches.first;
      expect(batch.availableSlots, 24);
      expect(batch.isFull, isFalse);

      final full = BatchModel.fromJson(
          const {'maxStudents': 25, 'currentStudents': 25});
      expect(full.availableSlots, 0);
      expect(full.isFull, isTrue);

      // Over-booked must not report negative capacity.
      final over = BatchModel.fromJson(
          const {'maxStudents': 25, 'currentStudents': 30});
      expect(over.availableSlots, 0);
    });

    test('survives a completely empty payload', () {
      final batch = BatchModel.fromJson(const {});

      expect(batch.id, isNull);
      expect(batch.displayName, '');
      expect(batch.sessionStart, '');
      expect(batch.daysLabel, '');
      expect(batch.sport, isNull);
      expect(batch.coach, isNull);
      expect(batch.isActive, isFalse);
    });
  });

  group('nested sport and coach', () {
    test('reads the sport with its image', () {
      final sport = _page().batches.first.sport!;

      expect(sport.id, 19);
      expect(sport.name, 'Badminton');
      expect(sport.category, 'Indoor');
      expect(sport.image, contains('sports-1783573669024-335965277.png'));
    });

    test('reads the coach contact details', () {
      final coach = _page().batches.first.coach!;

      expect(coach.id, 23);
      expect(coach.name, 'Sudhanshu Medsikar');
      expect(coach.email, 'smedsikar@gmail.com');
      expect(coach.phone, '7507069898');
      expect(coach.ground, isNull, reason: '/batches does not include ground');
    });

    test('reads the ground from the by-sport variant', () {
      final coach = CoachRef.fromJson(
          jsonDecode(_bySportCoach) as Map<String, dynamic>);
      expect(coach.ground, 'Sinhagad Road');
    });
  });

  group('BatchStats', () {
    test('parses the stats payload', () {
      final decoded = jsonDecode(_statsJson) as Map<String, dynamic>;
      final stats =
          BatchStats.fromJson(decoded['data'] as Map<String, dynamic>);

      expect(stats.batchId, 53);
      expect(stats.batchName, '3 DAYS( Evening)');
      expect(stats.sport, 'Badminton');
      expect(stats.coach, 'Sudhanshu Medsikar');
      expect(stats.maxStudents, 25);
      expect(stats.currentStudents, 1);
      expect(stats.enrolledStudents, 0);
      expect(stats.availableSlots, 24);
      expect(stats.occupancyPercentage, 4);
      expect(stats.isFull, isFalse);
    });
  });
}
