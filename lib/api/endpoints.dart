class ApiConfig {
  ApiConfig._();

  // Backend base URL (must include /api)
  // For Render:
  static const String baseUrl = 'https://minor-backend-y0ge.onrender.com/api';

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

  // Face
  // Face (deprecated) - replaced by biometrics module
  // static const String faceRegister = '/face/register';
  // static const String faceVerify = '/face/verify';

  // Biometrics (hardware-backed, admin-gated)
  static const String biometricsRequestEnable = '/biometrics/request-enable';
  static const String biometricsStatus = '/biometrics/status';
  static const String biometricsPublicKey = '/biometrics/public-key';
  static const String biometricsCheckKey = '/biometrics/check-key';
  static const String biometricsRegisterKey = '/biometrics/register-key';
  static const String biometricsChallenge = '/biometrics/challenge';
  static const String biometricsValidate = '/biometrics/validate';
  static const String biometricsRevoke = '/biometrics/revoke';
  static const String biometricsAdminApprove = '/biometrics/admin/approve';
  static const String biometricsAdminRevoke = '/biometrics/admin/revoke';

  // Attendance (migrated into sessions)
  static String attendanceBySession(String sessionId) =>
      '/sessions/$sessionId/attendance';
  // Attendance biometric endpoints
  static const String attendanceCheckKey = '/attendance/check-key';
  static const String attendanceRegisterKey = '/attendance/register-key';
  static const String attendanceVerifyChallenge =
      '/attendance/verify-challenge';
  static const String attendanceMarkPresent = '/attendance/mark-present';
}
