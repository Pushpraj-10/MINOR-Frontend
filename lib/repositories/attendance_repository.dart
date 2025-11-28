import 'package:frontend/api/api_client.dart';

class AttendanceRepository {
  // Calls GET /biometrics/check (combined status + challenge)
  Future<Map<String, dynamic>> checkKey() async {
    return await ApiClient.I.biometricCheck();
  }

  // Calls POST /biometrics/register-key
  Future<Map<String, dynamic>> registerKey(
      {required String publicKeyPem}) async {
    await ApiClient.I.registerBiometricKey(publicKeyPem: publicKeyPem);
    return {
      'ok': true
    }; // registerBiometricKey returns void, so we return success
  }

  // Calls POST /attendance/verify-challenge
  Future<Map<String, dynamic>> verifyChallenge(
      {required String challenge,
      required String signature,
      String? qrToken,
      String? sessionId}) async {
    return await ApiClient.I.attendanceVerifyChallenge(
        challenge: challenge,
        signature: signature,
        qrToken: qrToken,
        sessionId: sessionId);
  }

  // Calls POST /attendance/mark-present
  Future<Map<String, dynamic>> markPresent(
      {String? studentUid, String? qrToken, String? sessionId}) async {
    return await ApiClient.I.attendanceMarkPresent(
        studentUid: studentUid, qrToken: qrToken, sessionId: sessionId);
  }
}
