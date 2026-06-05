/// API endpoint constants
class ApiEndpoints {
  static const String baseUrl = '/api';

  // Authentication
  static const String login = '$baseUrl/auth/token/';
  static const String register = '$baseUrl/auth/register/';
  static const String ocrPreviewSession = '$baseUrl/auth/ocr-preview/session/';
  static const String ocrPreview = '$baseUrl/auth/ocr-preview/';
  static const String refreshToken = '$baseUrl/auth/token/refresh/';
  static const String logout = '$baseUrl/auth/logout/';
  static const String verifyEmail = '$baseUrl/auth/verify-email/';
  static const String verifyEmailCode = '$baseUrl/auth/verify-email-code/';
  static const String resendVerificationEmail =
      '$baseUrl/auth/resend-verification-email/';
  static const String updateUnverifiedEmail =
      '$baseUrl/auth/update-unverified-email/';
  static const String requestPasswordReset =
      '$baseUrl/auth/request-password-reset/';
  static const String confirmPasswordReset =
      '$baseUrl/auth/confirm-reset-password/';

  // Social Sign-In
  static const String googleSignIn = '$baseUrl/auth/google/';
  static const String appleSignIn = '$baseUrl/auth/apple/';
  static const String googleComplete = '$baseUrl/auth/google-complete/';
  static const String socialComplete = '$baseUrl/auth/social-complete/';

  // Account Linking
  static const String linkGoogle = '$baseUrl/auth/link-google/';
  static const String linkApple = '$baseUrl/auth/link-apple/';

  // Current User
  static const String me = '$baseUrl/me/';

  // Applicants (Self-service)
  static const String myProfile = '$baseUrl/applicants/me/profile/';
  static const String myWorkExperiences =
      '$baseUrl/applicants/me/work_experiences/';
  static const String myDocuments = '$baseUrl/applicants/me/documents/';

  /// Checklist tipe dokumen (INITIAL saja sampai lamaran capai INTERVIEW+).
  static const String myDocumentTypes =
      '$baseUrl/applicants/me/document-types/';
  static const String myApplications = '$baseUrl/applicants/me/applications/';
  static const String changePassword =
      '$baseUrl/applicants/me/change-password/';
  static const String myBiodataPdf = '$baseUrl/applicants/me/biodata-pdf/';
  static const String myPsychologyReferralPdf =
      '$baseUrl/applicants/me/psychology-referral-pdf/';
  static const String myMedicalReferralPdf =
      '$baseUrl/applicants/me/medical-referral-pdf/';

  // Account Deletion
  static const String myDeletionRequest = '$baseUrl/deletion-requests/my/';
  static const String submitDeletionRequest =
      '$baseUrl/deletion-requests/submit/';
  static const String cancelDeletionRequest =
      '$baseUrl/deletion-requests/my/cancel/';

  // Public
  static const String publicJobs = '$baseUrl/jobs/public/';
  static const String publicNews = '$baseUrl/news/public/';
  static const String publicDocumentTypes = '$baseUrl/document-types/public/';
  static const String publicStaffReferrers = '$baseUrl/staff-referrers/';

  // Jobs
  static String jobDetail(int id) => '$baseUrl/jobs/public/$id/';

  // Applicant Applications
  static String applicationDetail(int id) =>
      '$baseUrl/applicants/me/applications/$id/';
  static String confirmAttendance(int id) =>
      '$baseUrl/applicants/me/applications/$id/confirm/';
  static String confirmDocumentStep(int id) =>
      '$baseUrl/applicants/me/applications/$id/confirm-step/';
  static String completeApplication(int id) =>
      '$baseUrl/applicants/me/applications/$id/complete/';
  static String applicationAnnouncements(int id) =>
      '$baseUrl/applicants/me/applications/$id/announcements/';

  // Chat (applicant side)
  static const String chatThreads = '$baseUrl/chat/applicant/threads/';
  static String chatMessages(int applicationId) =>
      '$baseUrl/chat/applicant/thread/$applicationId/messages/';
  static String chatSend(int applicationId) =>
      '$baseUrl/chat/applicant/thread/$applicationId/messages/';
  static String chatMarkRead(int applicationId) =>
      '$baseUrl/chat/applicant/thread/$applicationId/read/';

  // News
  static String newsDetail(int id) => '$baseUrl/news/public/$id/';

  // Notifications
  static const String notifications = '$baseUrl/notifications/';
  static String notificationDetail(int id) => '$baseUrl/notifications/$id/';
  static String markNotificationRead(int id) =>
      '$baseUrl/notifications/$id/mark-read/';
  static const String markAllNotificationsRead =
      '$baseUrl/notifications/mark-all-read/';

  // FCM Device Token
  static const String fcmRegister = '$baseUrl/fcm/register/';
  static const String fcmUnregister = '$baseUrl/fcm/unregister/';

  // Documents
  static String documentOcrPrefill(int id) =>
      '$baseUrl/applicants/me/documents/$id/ocr_prefill/';

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

  /// Returns village detail with parent kecamatan info (district, district_name).
  static String villageDetail(int id) => '$baseUrl/villages/$id/';
}
