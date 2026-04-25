import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'core/navigation/main_tab_transition.dart';
import 'core/widgets/custom_toast.dart';

import 'features/auth/presentation/pages/splash_page.dart';
import 'features/auth/presentation/pages/login_page_new.dart';
import 'features/auth/presentation/pages/registration_page_new.dart';
import 'features/auth/presentation/pages/social_complete_profile_page.dart';
import 'features/auth/presentation/pages/email_verification_page.dart';
import 'features/auth/presentation/pages/forgot_password_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/profile/presentation/pages/edit_profile_page.dart';
import 'features/profile/presentation/pages/work_experiences_page.dart';
import 'features/profile/presentation/pages/change_password_page.dart';
import 'features/profile/presentation/pages/account_deletion_request_page.dart';
import 'features/documents/presentation/pages/documents_page.dart';
import 'features/documents/presentation/pages/upload_document_page.dart';
import 'features/jobs/presentation/pages/jobs_list_page.dart';
import 'features/jobs/presentation/pages/job_detail_page.dart';
import 'features/jobs/presentation/pages/my_applications_page.dart';
import 'features/jobs/presentation/pages/application_detail_page.dart';
import 'features/chat/presentation/pages/chat_inbox_page.dart';
import 'features/chat/presentation/pages/chat_thread_page.dart';
import 'features/news/presentation/pages/news_list_page.dart';
import 'features/news/presentation/pages/news_detail_page.dart';
import 'features/notifications/presentation/pages/notifications_page.dart';
import 'features/notifications/presentation/pages/notification_detail_page.dart';
import 'features/notifications/presentation/pages/notification_settings_page.dart';
import 'features/auth/data/providers/auth_provider.dart';
import 'features/profile/data/providers/profile_provider.dart';
import 'features/documents/data/providers/document_provider.dart';
import 'config/strings.dart';

/// A [ChangeNotifier] that bridges Riverpod [AuthState] changes to GoRouter's
/// [refreshListenable], so the router is created ONCE and only re-evaluates
/// its redirect function when auth state changes — without rebuilding the
/// whole widget tree.
class _AuthRouterNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthRouterNotifier();

  // Listen to auth state changes and:
  // - notify the router so redirects are re-evaluated
  // - clear user-scoped cached data when logging out, so a new login
  //   never sees stale profile/documents from the previous account.
  ref.listen<AuthState>(authStateProvider, (previous, next) {
    final wasAuthenticated = previous?.isAuthenticated ?? false;
    final isAuthenticated = next.isAuthenticated;

    // When transitioning from logged-in → logged-out, clear all
    // user-scoped providers so the next session starts clean.
    if (wasAuthenticated && !isAuthenticated) {
      ref.invalidate(profileNotifierProvider);
      ref.invalidate(myDocumentsProvider);
      ref.invalidate(documentChecklistProvider);
      ref.invalidate(workExperienceNotifierProvider);
      ref.invalidate(accountDeletionRequestProvider);
    }

    // When transitioning from logged-out → logged-in, eagerly load
    // fresh data for the new user so no page ever sees stale data.
    if (!wasAuthenticated && isAuthenticated) {
      // Ensure a fresh provider instance, then force a reload.
      ref.invalidate(profileNotifierProvider);
      ref.invalidate(myDocumentsProvider);
      ref.invalidate(documentChecklistProvider);
      ref.invalidate(workExperienceNotifierProvider);
      ref.invalidate(accountDeletionRequestProvider);
      ref.read(profileNotifierProvider.notifier).loadProfile(force: true);
    }

    authNotifier.notify();
  });

  ref.onDispose(authNotifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Splash handles its own auth-aware navigation — never redirect away.
      if (loc == '/splash') return null;

      // Read current auth state at redirect-evaluation time.
      final authState = ref.read(authStateProvider);
      final isAuthenticated = authState.isAuthenticated;

      // Pre-auth routes: login, register, email verification, and password reset.
      final isPreAuthRoute = loc == '/login' ||
                            loc == '/register' || 
                            loc.startsWith('/email-verification') ||
                            loc == '/forgot-password' ||
                            loc.startsWith('/reset-password');

      if (!isAuthenticated) {
        // Unauthenticated users can only access pre-auth routes.
        return isPreAuthRoute ? null : '/login';
      }

      // Social-complete is a post-auth onboarding route — allow it.
      if (loc == '/social-complete') return null;

      // Authenticated but email not verified — must verify before accessing app.
      final emailVerified = authState.user?.emailVerified ?? true;
      if (!emailVerified) {
        final userEmail = Uri.encodeComponent(authState.user!.email);
        return loc.startsWith('/email-verification')
            ? null
            : '/email-verification?email=$userEmail';
      }

      // Authenticated & complete — send away from pre-auth routes.
      if (isPreAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashPage(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          transitionsBuilder: (_, _, _, child) => child,
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginPageNew(),
          transitionDuration: const Duration(milliseconds: 450),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeIn,
            ),
            child: child,
          ),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegistrationPageNew(),
      ),
      GoRoute(
        path: '/social-complete',
        name: 'social-complete',
        builder: (context, state) => const SocialCompleteProfilePage(),
      ),
      GoRoute(
        path: '/email-verification',
        name: 'email-verification',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'] ?? '';
          return EmailVerificationPage(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) {
          final uid = state.uri.queryParameters['uid'];
          final token = state.uri.queryParameters['token'];
          return ResetPasswordPage(uid: uid ?? '', token: token ?? '');
        },
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => MainTabTransition.buildPage(
          key: state.pageKey,
          location: state.matchedLocation,
          child: const HomePage(),
        ),
      ),
      GoRoute(
        path: '/notifications/:notificationId',
        name: 'notification-detail',
        builder: (context, state) {
          final id =
              int.tryParse(state.pathParameters['notificationId'] ?? '') ?? 0;
          return NotificationDetailPage(notificationId: id);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/settings/notifications',
        name: 'notification-settings',
        builder: (context, state) => const NotificationSettingsPage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => MainTabTransition.buildPage(
          key: state.pageKey,
          location: state.matchedLocation,
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: '/profile/work-experiences',
        name: 'work-experiences',
        builder: (context, state) => const WorkExperiencesPage(),
      ),
      GoRoute(
        path: '/profile/change-password',
        name: 'change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/profile/account-deletion',
        name: 'account-deletion',
        builder: (context, state) => const AccountDeletionRequestPage(),
      ),
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (context, state) => const DocumentsPage(),
      ),
      GoRoute(
        path: '/documents/upload',
        name: 'upload-document',
        builder: (context, state) {
          final typeId = state.uri.queryParameters['type'];
          return UploadDocumentPage(
            documentTypeId: typeId != null ? int.tryParse(typeId) : null,
          );
        },
      ),
      GoRoute(
        path: '/jobs',
        name: 'jobs',
        pageBuilder: (context, state) => MainTabTransition.buildPage(
          key: state.pageKey,
          location: state.matchedLocation,
          child: const JobsListPage(),
        ),
      ),
      // Must come before /jobs/:id so GoRouter doesn't match "my-applications" as an :id
      GoRoute(
        path: '/jobs/my-applications',
        name: 'my-applications',
        pageBuilder: (context, state) => MainTabTransition.buildPage(
          key: state.pageKey,
          location: state.matchedLocation,
          child: const MyApplicationsPage(),
        ),
      ),
      // Must come before /jobs/:id so GoRouter doesn't match "applications" as an :id
      GoRoute(
        path: '/jobs/applications/:id',
        name: 'application-detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ApplicationDetailPage(applicationId: id);
        },
      ),
      GoRoute(
        path: '/jobs/applications/:id/chat',
        name: 'application-chat',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ChatThreadPage(applicationId: id);
        },
      ),
      GoRoute(
        path: '/jobs/:id',
        name: 'job-detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return JobDetailPage(jobId: id);
        },
      ),
      GoRoute(
        path: '/news',
        name: 'news',
        pageBuilder: (context, state) => MainTabTransition.buildPage(
          key: state.pageKey,
          location: state.matchedLocation,
          child: const NewsListPage(),
        ),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) => const ChatInboxPage(),
      ),
      GoRoute(
        path: '/news/:id',
        name: 'news-detail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return NewsDetailPage(newsId: id);
        },
      ),
    ],
  );
});

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
