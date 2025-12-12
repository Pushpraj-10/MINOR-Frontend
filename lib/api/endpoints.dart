class ApiConfig {
  ApiConfig._();

  // Backend base URL (must include /api)
  // For Render:
  static const String baseUrl = 'https://minor-backend-firestore.onrender.com/api';

  // Auth
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authRefresh = '/auth/refresh';
  static const String authLogout = '/auth/logout';
  static const String authMe = '/auth/me';
  static const String authUsers = '/auth/users';

  // Sessions
  static const String sessions = '/sessions';
  static const String sessionsCheckin = '/sessions/checkin';
  static const String professorSessions = '/sessions/professor';
  static String professorSessionAttendance(String sessionId) =>
      '/sessions/professor/$sessionId/attendance';

  // Biometrics (hardware-backed, admin-gated)
  static const String biometricsRequestEnable = '/biometrics/request-enable';
  static const String biometricsStatus = '/biometrics/status';
  static const String biometricsPublicKey = '/biometrics/public-key';
  static const String biometricsCheck =
      '/biometrics/check'; // New combined endpoint
  static const String biometricsCheckKey = '/biometrics/check-key';
  static const String biometricsRegisterKey = '/biometrics/register-key';
  static const String biometricsChallenge = '/biometrics/challenge';
  static const String biometricsValidate = '/biometrics/validate';
  static const String biometricsRevoke = '/biometrics/revoke';
  static const String biometricsDeleteKey = '/biometrics/delete-key';
  static const String biometricsAdminApprove = '/biometrics/admin/approve';
  static const String biometricsAdminRevoke = '/biometrics/admin/revoke';

  // Attendance (migrated into sessions)
  static String attendanceBySession(String sessionId) =>
      '/sessions/$sessionId/attendance';

  // Attendance biometric endpoints (now use biometrics endpoints)
  static const String attendanceVerifyChallenge =
      '/attendance/verify-challenge';
  static const String attendanceMarkPresent = '/attendance/mark-present';
  static const String attendanceTakeLeave = '/attendance/take-leave';
  static String attendanceGetStatics(String userId) =>
      '/attendance/statistics/$userId';
  static String attendanceUserRecords(String userId) =>
      '/attendance/records/$userId';
  static const String attendanceStudentsByBatch =
      '/attendance/students/by-batch';

  // Admin
  static const String adminUsers = '/admin/users';
  static String adminUserRole(String uid) => '/admin/users/$uid/role';
  static const String adminBiometricRequests = '/admin/biometrics/requests';
  static String adminBiometricApprove(String userId) =>
      '/admin/biometrics/requests/$userId/approve';
  static const String adminBulkUsersPreview = '/admin/users/bulk/preview';
  static const String adminBulkUsersImport = '/admin/users/bulk/import';
  static const String leaveRequest = '/leave/request';
  static const String leaveMy = '/leave/my';
  static const String leaveAll = '/leave/all';
  static String leaveDecision(String leaveId) => '/leave/$leaveId/decision';
  // Check if a user has an approved active leave for current date
  static const String leaveActive = '/leave/active';
}
