import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/data/profile_patch.dart';

void main() {
  test('omits unchanged fields including blank strings', () {
    final baseline = {
      'full_name': 'ADA',
      'passport_number': 'X123',
      'height_cm': 170,
    };
    final current = {
      'full_name': 'ADA',
      'passport_number': 'X123',
      'height_cm': 170,
      'family_card_number': '',
    };
    expect(
      changedProfileFields(baseline: baseline, current: current),
      {'family_card_number': ''},
    );
  });

  test('sends a field the user cleared', () {
    final patch = changedProfileFields(
      baseline: {'passport_number': 'X123'},
      current: {'passport_number': ''},
    );
    expect(patch, {'passport_number': ''});
  });

  test('does not wipe blanks that were already blank after a failed hydrate', () {
    final patch = changedProfileFields(
      baseline: {'passport_number': '', 'height_cm': null},
      current: {'passport_number': '', 'height_cm': null},
    );
    expect(patch, isEmpty);
  });
}
