import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/models/profile_model.dart';

/// The exact payload shape documented for `GET /auth/profile`.
const Map<String, dynamic> _apiUser = {
  "id": 569,
  "name": "Rahul Sharma",
  "phone_number": "9876543210",
  "email": "rahul@example.com",
  "googleId": null,
  "isGoogleUser": false,
  "role": "USER",
  "sportComplexId": null,
  "total_bookings": 0,
  "membership_type": null,
  "status": "Active",
  "join_date": "2026-07-27",
  "last_active": null,
  "avatar": null,
  "employee_id": null,
  "department": null,
  "assigned_sports": null,
  "assigned_location": null,
  "permissions": [],
  "profile_picture": null,
};

void main() {
  group('ProfileModel.fromJson', () {
    test('maps every documented field', () {
      final profile = ProfileModel.fromJson(_apiUser);

      expect(profile.id, 569);
      expect(profile.name, 'Rahul Sharma');
      expect(profile.phoneNumber, '9876543210');
      expect(profile.email, 'rahul@example.com');
      expect(profile.googleId, isNull);
      expect(profile.isGoogleUser, isFalse);
      expect(profile.role, 'USER');
      expect(profile.sportComplexId, isNull);
      expect(profile.totalBookings, 0);
      expect(profile.membershipType, isNull);
      expect(profile.status, 'Active');
      expect(profile.joinDate, '2026-07-27');
      expect(profile.lastActive, isNull);
      expect(profile.avatar, isNull);
      expect(profile.employeeId, isNull);
      expect(profile.department, isNull);
      expect(profile.assignedSports, isEmpty);
      expect(profile.assignedLocation, isNull);
      expect(profile.permissions, isEmpty);
      expect(profile.profilePicture, isNull);
    });

    test('survives a completely empty payload', () {
      final profile = ProfileModel.fromJson(const {});

      expect(profile.isEmpty, isTrue);
      expect(profile.displayName, '');
      expect(profile.initial, '?');
      expect(profile.imageUrl, isNull);
      expect(profile.membershipLabel, 'N/A');
      expect(profile.permissions, isEmpty);
    });

    test('accepts camelCase and legacy spellings', () {
      final profile = ProfileModel.fromJson(const {
        'phoneNumber': '111',
        'membershipType': 'Gold',
        'profilePicture': 'https://cdn/x.png',
        'totalBookings': '12',
        'isGoogleUser': 1,
      });

      expect(profile.phoneNumber, '111');
      expect(profile.membershipLabel, 'Gold');
      expect(profile.imageUrl, 'https://cdn/x.png');
      expect(profile.totalBookings, 12);
      expect(profile.isGoogleUser, isTrue);
    });

    test('treats blank and "null" strings as absent', () {
      final profile = ProfileModel.fromJson(const {
        'name': '   ',
        'profile_picture': '',
        'avatar': 'null',
      });

      expect(profile.name, isNull);
      expect(profile.initial, '?');
      expect(profile.imageUrl, isNull);
    });

    test('prefers profile_picture over avatar', () {
      final profile = ProfileModel.fromJson(const {
        'avatar': 'https://cdn/avatar.png',
        'profile_picture': 'https://cdn/picture.png',
      });

      expect(profile.imageUrl, 'https://cdn/picture.png');
      expect(profile.hasImage, isTrue);
    });

    test('falls back to avatar when there is no profile picture', () {
      final profile =
          ProfileModel.fromJson(const {'avatar': 'https://cdn/avatar.png'});
      expect(profile.imageUrl, 'https://cdn/avatar.png');
    });
  });

  group('permissions', () {
    const permissions = [
      'user_dashboard',
      'user_logout',
      'user_my_bookings',
    ];

    test('parses a list', () {
      final profile = ProfileModel.fromJson(const {'permissions': permissions});

      expect(profile.permissions, permissions);
      expect(profile.hasPermission('user_dashboard'), isTrue);
      expect(profile.hasPermission('admin_everything'), isFalse);
    });

    test('parses a comma separated string', () {
      final profile = ProfileModel.fromJson(
          const {'permissions': 'user_dashboard, user_logout'});
      expect(profile.permissions, ['user_dashboard', 'user_logout']);
    });

    test('parses a JSON-encoded array', () {
      final profile = ProfileModel.fromJson(
          const {'permissions': '["user_dashboard","user_logout"]'});
      expect(profile.permissions, ['user_dashboard', 'user_logout']);
    });
  });

  group('derived values', () {
    test('initial is the uppercased first letter', () {
      expect(ProfileModel.fromJson(const {'name': 'rahul'}).initial, 'R');
      expect(ProfileModel.fromJson(const {'name': '  asha'}).initial, 'A');
    });

    test('role helpers normalise case', () {
      final profile = ProfileModel.fromJson(const {'role': 'ADMIN'});
      expect(profile.roleLabel, 'ADMIN');
      expect(profile.normalisedRole, 'admin');
    });

    test('isActive reads the status field', () {
      expect(ProfileModel.fromJson(const {'status': 'Active'}).isActive, isTrue);
      expect(
          ProfileModel.fromJson(const {'status': 'Suspended'}).isActive, isFalse);
      expect(ProfileModel.fromJson(const {}).isActive, isFalse);
    });
  });

  group('round-tripping', () {
    test('encode/decode preserves the profile', () {
      final original = ProfileModel.fromJson(_apiUser);
      final restored = ProfileModel.decode(original.encode());

      expect(restored, original);
    });

    test('decode tolerates corrupt cache entries', () {
      expect(ProfileModel.decode('not json'), isNull);
      expect(ProfileModel.decode(null), isNull);
      expect(ProfileModel.decode(''), isNull);
    });

    test('keeps unmapped fields so legacy screens still work', () {
      final profile = ProfileModel.fromJson(const {
        'id': 7,
        'name': 'Asha',
        'student_id': 42,
        'passcode': 'abc123',
      });

      expect(profile.extras['student_id'], 42);
      expect(profile.extras['passcode'], 'abc123');

      final legacy = profile.toLegacyUserMap();
      expect(legacy['student_id'], 42);
      expect(legacy['passcode'], 'abc123');
      expect(legacy['id'], 7);

      // Survives a cache round-trip too.
      final restored = ProfileModel.decode(profile.encode())!;
      expect(restored.extras['passcode'], 'abc123');
    });

    test('legacy map falls back to the user id when there is no student id', () {
      final legacy =
          ProfileModel.fromJson(const {'id': 9}).toLegacyUserMap();
      expect(legacy['student_id'], 9);
    });

    test('legacy map exposes the phone and photo aliases', () {
      final legacy = ProfileModel.fromJson(const {
        'phone_number': '555',
        'profile_picture': 'https://cdn/p.png',
      }).toLegacyUserMap();

      expect(legacy['phone'], '555');
      expect(legacy['photo'], 'https://cdn/p.png');
    });
  });
}
