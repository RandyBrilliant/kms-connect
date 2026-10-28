import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/domain/models/applicant_profile.dart';
import 'package:mobile/features/profile/domain/profile_completion.dart';

ApplicantProfile _profile({
  String status = 'SUBMITTED',
  String? bank,
  String? holder,
  String? noRek,
}) =>
    ApplicantProfile(
      id: 1,
      verificationStatus: status,
      bank: bank,
      bankAccountHolder: holder,
      noRek: noRek,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  test('missing bank data prompts but never blocks the app', () {
    final withoutBank = _profile();
    final withBank = _profile(bank: 'BRI', holder: 'SITI', noRek: '0021010001');
    expect(needsBankAccount(withoutBank), isTrue);
    // Completion gate (onboarding redirect) ignores rekening entirely.
    expect(
      evaluateProfileCompletion(withoutBank).sections,
      evaluateProfileCompletion(withBank).sections,
    );
  });

  test('complete rekening does not prompt', () {
    expect(
      needsBankAccount(
        _profile(bank: 'BRI', holder: 'SITI', noRek: '0021010001'),
      ),
      isFalse,
    );
  });

  test('non-digit nomor rekening still prompts', () {
    expect(
      needsBankAccount(_profile(bank: 'BRI', holder: 'SITI', noRek: '0021-01')),
      isTrue,
    );
  });

  test('accepted / rejected profiles are never prompted', () {
    expect(needsBankAccount(_profile(status: 'ACCEPTED')), isFalse);
    expect(needsBankAccount(_profile(status: 'REJECTED')), isFalse);
  });
}
