/// API endpoint constants
class ApiEndpoints {
  static const String baseUrl = '/api';

  // Authentication
  static const String login = '$baseUrl/auth/token/';
  static const String register = '$baseUrl/auth/register/';
  static const String googleAuth = '$baseUrl/auth/google/';
  static const String ocrPreview = '$baseUrl/auth/ocr-preview/';
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
  static const String publicStaffReferrers = '$baseUrl/staff-referrers/';

  // Jobs
  static String jobDetail(int id) => '$baseUrl/jobs/public/$id/';
  static String applyForJob(int id) => '$baseUrl/jobs/$id/apply/';

  // Applicant Applications
  static String applicationDetail(int id) => '$baseUrl/applicants/me/applications/$id/';

  // Chat (applicant side)
  static const String chatThreads = '$baseUrl/chat/applicant/threads/';
  static String chatMessages(int applicationId) =>
      '$baseUrl/chat/applicant/thread/$applicationId/messages/';
  static String chatSend(int applicationId) =>
      '$baseUrl/chat/applicant/thread/$applicationId/send/';
  static String chatMarkRead(int applicationId) =>
      '$baseUrl/chat/applicant/thread/$applicationId/mark-read/';

  // News
  static String newsDetail(int id) => '$baseUrl/news/public/$id/';

  // Notifications
  static const String notifications = '$baseUrl/notifications/';
  static String markNotificationRead(int id) => '$baseUrl/notifications/$id/mark-read/';
  static const String markAllNotificationsRead = '$baseUrl/notifications/mark-all-read/';

  // FCM Device Token
  static const String fcmRegister = '$baseUrl/fcm/register/';
  static const String fcmUnregister = '$baseUrl/fcm/unregister/';
  
  // Documents
  static String documentOcrPrefill(int id) => '$baseUrl/applicants/me/documents/$id/ocr_prefill/';

  // Regions (public, no auth required)
  static const String provinces = '$baseUrl/provinces/';
  static const String regencies = '$baseUrl/regencies/';
  static const String districts = '$baseUrl/districts/';
  static const String villages = '$baseUrl/villages/';

  // Region helpers with filter params
  static String regenciesByProvince(int provinceId) =>
      '$baseUrl/regencies/?province_id=$provinceId';
  static String districtsByRegency(int regencyId) =>
      '$baseUrl/districts/?regency_id=$regencyId';
  static String villagesByDistrict(int districtId) =>
      '$baseUrl/villages/?district_id=$districtId';
}
