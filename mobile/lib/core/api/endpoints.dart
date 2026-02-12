/// API endpoint constants
class ApiEndpoints {
  static const String baseUrl = '/api';

  // Authentication
  static const String login = '$baseUrl/auth/token/';
  static const String register = '$baseUrl/auth/register/';
  static const String googleAuth = '$baseUrl/auth/google/';
  static const String refreshToken = '$baseUrl/auth/token/refresh/';
  static const String logout = '$baseUrl/auth/logout/';
  static const String verifyEmail = '$baseUrl/auth/verify-email/';
  static const String requestPasswordReset = '$baseUrl/auth/request-password-reset/';
  static const String confirmPasswordReset = '$baseUrl/auth/confirm-reset-password/';

  // Current User
  static const String me = '$baseUrl/me/';

  // Applicants (Self-service)
  static const String myProfile = '$baseUrl/applicants/me/profile/';
  static const String myWorkExperiences = '$baseUrl/applicants/me/work_experiences/';
  static const String myDocuments = '$baseUrl/applicants/me/documents/';
  static const String myApplications = '$baseUrl/applicants/me/applications/';

  // Public
  static const String publicJobs = '$baseUrl/jobs/public/';
  static const String publicNews = '$baseUrl/news/public/';
  static const String publicDocumentTypes = '$baseUrl/document-types/public/';

  // Jobs
  static String jobDetail(int id) => '$baseUrl/jobs/public/$id/';
  static String applyForJob(int id) => '$baseUrl/jobs/$id/apply/';

  // News
  static String newsDetail(int id) => '$baseUrl/news/public/$id/';
  
  // Documents
  static String documentOcrPrefill(int id) => '$baseUrl/applicants/me/documents/$id/ocr_prefill/';
}
