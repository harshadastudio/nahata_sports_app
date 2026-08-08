import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/features/employee/data/models/employee_mappers.dart';
import 'package:nahata_app/features/employee/domain/entities/employee_staff_details.dart';

/// Tests for `GET /auth/staff-details`, which backs the Employment Details
/// block on the employee's My Profile screen.
///
/// The route answers untyped `{label, value}` pairs so the same envelope serves
/// every staff role. That makes the mapper the only place a shape mistake can
/// hide, which is what these pin down.
void main() {
  /// A response with the fields an employee record actually returns.
  ///
  /// Copied from a live EMPLOYEE account rather than invented: the date is
  /// already formatted server-side (`toLocaleDateString('en-IN', …)`), so
  /// nothing on this side parses or re-renders it.
  String employeeResponse() => jsonEncode({
        'success': true,
        'data': {
          'role': 'EMPLOYEE',
          'sections': [
            {
              'title': 'Employment Details',
              'fields': [
                {'label': 'Employee ID', 'value': 'EMP006'},
                {'label': 'Designation', 'value': 'Manager'},
                {'label': 'Department', 'value': 'Operations'},
                {'label': 'Shift', 'value': 'Morning'},
                {'label': 'Joining Date', 'value': '07 Aug 2026'},
                {'label': 'Status', 'value': 'Active'},
                {'label': 'Sports Complex', 'value': 'Sinhagad Road'},
                {'label': 'Contact Number', 'value': '9856451235'},
              ],
            },
            {
              'title': 'Account',
              'fields': [
                {'label': 'Assigned Location', 'value': 'Sinhagad Road'},
                {'label': 'Account Status', 'value': 'Active'},
              ],
            },
          ],
        },
      });

  group('staffDetails mapping', () {
    test('reads every field of a live employee response, in order', () {
      final details =
          EmployeeMappers.staffDetails(jsonDecode(employeeResponse()));

      expect(details.role, 'EMPLOYEE');
      expect(details.isEmpty, isFalse);
      expect(details.sections, hasLength(2));

      final employment = details.sections.first;
      expect(employment.title, 'Employment Details');

      // Order matters — the backend sends them in the order the admin form
      // presents them, and the screen renders them as given.
      expect(
        employment.fields.map((f) => f.label).toList(),
        <String>[
          'Employee ID',
          'Designation',
          'Department',
          'Shift',
          'Joining Date',
          'Status',
          'Sports Complex',
          'Contact Number',
        ],
      );
      expect(
        employment.fields.map((f) => f.value).toList(),
        <String>[
          'EMP006',
          'Manager',
          'Operations',
          'Morning',
          '07 Aug 2026',
          'Active',
          'Sinhagad Road',
          '9856451235',
        ],
      );

      expect(details.sections.last.title, 'Account');
      expect(details.sections.last.fields, hasLength(2));
    });

    test('drops a field with no value rather than showing a bare label', () {
      // The backend already filters these, but a null slipping through would
      // otherwise render a label with nothing beside it, which reads as a
      // stuck loading state.
      final details = EmployeeMappers.staffDetails({
        'data': {
          'role': 'EMPLOYEE',
          'sections': [
            {
              'title': 'Employment Details',
              'fields': [
                {'label': 'Employee ID', 'value': 'EMP006'},
                {'label': 'Address', 'value': null},
                {'label': 'Shift', 'value': '   '},
                {'label': 'Department', 'value': 'null'},
                {'value': 'no label at all'},
              ],
            },
          ],
        },
      });

      expect(details.sections.single.fields, hasLength(1));
      expect(details.sections.single.fields.single.label, 'Employee ID');
    });

    test('drops a section that ends up with no fields', () {
      final details = EmployeeMappers.staffDetails({
        'data': {
          'role': 'EMPLOYEE',
          'sections': [
            {'title': 'Employment Details', 'fields': <dynamic>[]},
            {
              'title': 'Account',
              'fields': [
                {'label': 'Account Status', 'value': 'Active'},
              ],
            },
          ],
        },
      });

      expect(details.sections, hasLength(1));
      expect(details.sections.single.title, 'Account');
    });

    test('an account with no employee record behind it reads as empty', () {
      // Real state right after an admin creates the login but before the
      // employee record is filled in. The screen falls back to the login card.
      final details = EmployeeMappers.staffDetails({
        'data': {'role': 'EMPLOYEE', 'sections': <dynamic>[]},
      });

      expect(details.role, 'EMPLOYEE');
      expect(details.isEmpty, isTrue);
      expect(details.sections, isEmpty);
    });

    test('a malformed body does not throw', () {
      // Every other reader in this module tolerates a wrong type; this one has
      // to as well, because a failure here would blank My Profile.
      expect(EmployeeMappers.staffDetails(null).isEmpty, isTrue);
      expect(EmployeeMappers.staffDetails('nonsense').isEmpty, isTrue);
      expect(
        EmployeeMappers.staffDetails({'data': {'sections': 'not a list'}}).isEmpty,
        isTrue,
      );
      expect(
        EmployeeMappers.staffDetails({
          'data': {
            'sections': [
              {'title': 'Employment Details', 'fields': 'not a list'},
            ],
          },
        }).isEmpty,
        isTrue,
      );
    });
  });

  group('EmployeeStaffDetails', () {
    test('is empty when every section is', () {
      const details = EmployeeStaffDetails(
        role: 'EMPLOYEE',
        sections: [EmployeeStaffSection(title: 'Employment Details')],
      );

      expect(details.isEmpty, isTrue);
    });

    test('is not empty once any section carries a field', () {
      const details = EmployeeStaffDetails(
        role: 'EMPLOYEE',
        sections: [
          EmployeeStaffSection(
            title: 'Employment Details',
            fields: [EmployeeStaffField(label: 'Employee ID', value: 'EMP006')],
          ),
        ],
      );

      expect(details.isEmpty, isFalse);
    });
  });
}
