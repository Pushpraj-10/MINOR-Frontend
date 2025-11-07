class ApiConfig {
  ApiConfig._();

  // Change to match your backend origin
  static const String baseUrl = String.fromEnvironment(
    'https://minor-backend-production.up.railway.app/api',
    defaultValue: 'https://minor-backend-production.up.railway.app/api',
  );

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
  static const String faceRegister = '/face/register';
  static const String faceVerify = '/face/verify';

  // Attendance
  static String attendanceBySession(String sessionId) =>
      '/attendance/$sessionId';
}
