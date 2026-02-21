import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/registration_page_new.dart';
import 'features/auth/presentation/pages/verify_email_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';
import 'features/home/presentation/pages/home_page.dart';
import 'features/profile/presentation/pages/profile_page.dart';
import 'features/profile/presentation/pages/edit_profile_page.dart';
import 'features/documents/presentation/pages/documents_page.dart';
import 'features/documents/presentation/pages/upload_document_page.dart';
import 'features/jobs/presentation/pages/jobs_list_page.dart';
import 'features/jobs/presentation/pages/job_detail_page.dart';
import 'features/jobs/presentation/pages/my_applications_page.dart';
import 'features/news/presentation/pages/news_list_page.dart';
import 'features/news/presentation/pages/news_detail_page.dart';
import 'features/auth/data/providers/auth_provider.dart';
import 'config/strings.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/home' : '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      
      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }
      if (isAuthenticated && isLoginRoute) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegistrationPageNew(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return VerifyEmailPage(token: token ?? '');
        },
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
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) => const EditProfilePage(),
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
        builder: (context, state) => const JobsListPage(),
      ),
      GoRoute(
        path: '/jobs/:id',
        name: 'job-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return JobDetailPage(jobId: id);
        },
      ),
      GoRoute(
        path: '/jobs/my-applications',
        name: 'my-applications',
        builder: (context, state) => const MyApplicationsPage(),
      ),
      GoRoute(
        path: '/news',
        name: 'news',
        builder: (context, state) => const NewsListPage(),
      ),
      GoRoute(
        path: '/news/:id',
        name: 'news-detail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
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
      routerConfig: router,
    );
  }
}
