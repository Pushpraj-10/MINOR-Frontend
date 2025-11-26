import 'package:frontend/api/api_client.dart';

class AttendanceRepository {
  // Calls GET /attendance/check-key
  Future<Map<String, dynamic>> checkKey() async {
    return await ApiClient.I.attendanceCheckKey();
  }

  // Calls POST /attendance/register-key
  Future<Map<String, dynamic>> registerKey(
      {required String publicKeyPem}) async {
    return await ApiClient.I.attendanceRegisterKey(publicKeyPem: publicKeyPem);
  }

  // Calls POST /attendance/verify-challenge
  Future<Map<String, dynamic>> verifyChallenge(
      {required String challenge, required String signature}) async {
    return await ApiClient.I
        .attendanceVerifyChallenge(challenge: challenge, signature: signature);
  }

  // Calls POST /attendance/mark-present
  Future<Map<String, dynamic>> markPresent(
      {String? studentUid, String? qrToken, String? sessionId}) async {
    return await ApiClient.I.attendanceMarkPresent(
        studentUid: studentUid, qrToken: qrToken, sessionId: sessionId);
  }
}
