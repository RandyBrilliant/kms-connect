import '../../features/auth/data/providers/auth_provider.dart';
import '../../features/profile/data/providers/profile_provider.dart';
import '../../features/profile/domain/profile_completion.dart';

/// Routes allowed while the applicant is completing mandatory biodata.
const kOnboardingProfileRoutes = {'/profile/complete', '/profile/edit'};

/// Routes reachable before the user is authenticated.
const kPreAuthRoutes = {
  '/login',
  '/register',
  '/forgot-password',
};

bool isPreAuthLocation(String loc) {
  return kPreAuthRoutes.contains(loc) ||
      loc.startsWith('/email-verification') ||
      loc.startsWith('/reset-password');
}

/// Resolves where an authenticated (or guest) user should be during onboarding.
///
/// Priority: profile checklist → email OTP → home.
String? resolveOnboardingRedirect({
  required String currentLocation,
  required AuthState authState,
  ProfileState? profileState,
}) {
  if (currentLocation == '/splash') return null;

  final isAuthenticated = authState.isAuthenticated;

  if (!isAuthenticated) {
    return isPreAuthLocation(currentLocation) ? null : '/login';
  }

  if (currentLocation == '/social-complete') return null;

  final user = authState.user!;
  final isApplicant = user.role.toUpperCase() == 'APPLICANT';

  if (isApplicant && profileState != null) {
    if (profileState.isLoading && profileState.profile == null) {
      return null;
    }
    if (profileState.error != null && profileState.profile == null) {
      return null;
    }

    final profile = profileState.profile;
    if (shouldBlockForIncompleteProfile(profile)) {
      if (!kOnboardingProfileRoutes.contains(currentLocation)) {
        return '/profile/complete';
      }
      return null;
    }

    // Profile complete but still on checklist — allow the page (shows CTA).
    if (currentLocation == '/profile/complete') {
      return null;
    }
  }

  if (!user.emailVerified) {
    final emailParam = Uri.encodeComponent(user.email);
    if (!currentLocation.startsWith('/email-verification')) {
      return '/email-verification?email=$emailParam';
    }
    return null;
  }

  if (isPreAuthLocation(currentLocation) || currentLocation == '/register') {
    return '/home';
  }

  return null;
}
