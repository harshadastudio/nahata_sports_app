import 'package:flutter_test/flutter_test.dart';
import 'package:nahata_app/repositories/coaching_repository.dart';

/// Coach 24 as `GET /coaches/sport/26` returns it, with the inline photo cut
/// down to a stub — the real one is two megabytes of base64.
const Map<String, dynamic> _liveCoach = {
  'id': 24,
  'name': 'Dashrath Birhamane',
  'email': 'das.010590@gmail.com',
  'phone': '8237468642',
  'sportId': 26,
  'sportComplexId': 1,
  'ground': 'Sinhagad Road',
  'price': '0.00',
  'availability': 'Monday,Tuesday,Sunday',
  'certification': 'ALL India Basketball Cert',
  'bio': 'This is Coach Bio',
  'image': 'data:image/png;base64,iVBORw0KGgo=',
  'status': 'Active',
};

void main() {
  group('CoachProfile from the live record', () {
    final profile =
        CoachProfile.fromJson(Map<String, dynamic>.from(_liveCoach));

    test('keeps the inline photo intact for the profile window', () {
      // Prefixing a data URI with the media host is what left the avatar
      // blank; it must come through byte for byte.
      expect(profile.image, 'data:image/png;base64,iVBORw0KGgo=');
      expect(profile.hasImage, isTrue);
    });

    test('reads the fields the profile sheet shows', () {
      expect(profile.id, 24);
      expect(profile.name, 'Dashrath Birhamane');
      expect(profile.ground, 'Sinhagad Road');
      expect(profile.bio, 'This is Coach Bio');
      expect(profile.certification, 'ALL India Basketball Cert');
      expect(profile.availability, 'Monday,Tuesday,Sunday');
    });

    test('a coach with none of the extras degrades to nulls, not blanks', () {
      final bare = CoachProfile.fromJson({'id': 23, 'name': 'Sudhanshu'});

      expect(bare.certification, isNull);
      expect(bare.availability, isNull);
      expect(bare.bio, isNull);
      expect(bare.hasImage, isFalse);
      // An empty credential line means the sheet drops the row entirely.
      expect(bare.credentials, isEmpty);
    });

    test('empty strings from the API count as absent', () {
      final blank = CoachProfile.fromJson({
        'id': 1,
        'certification': '   ',
        'availability': '',
        'image': '',
      });

      expect(blank.certification, isNull);
      expect(blank.availability, isNull);
      expect(blank.hasImage, isFalse);
    });
  });
}
