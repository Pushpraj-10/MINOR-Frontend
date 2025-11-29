import 'package:frontend/api/api_client.dart';

class AttendanceRepository {
  Future<Map<String, dynamic>> checkKey() async {
    final res = await ApiClient.I.biometricCheck();
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> registerKey({
    required String publicKeyPem,
  }) async {
    await ApiClient.I.registerBiometricKey(publicKeyPem: publicKeyPem);
    return {'ok': true};
  }

  Future<Map<String, dynamic>> verifyChallenge({
    required String challenge,
    required String signature,
    required String qrToken,
    String? sessionId,
    String? studentUid,
  }) async {
    final res = await ApiClient.I.attendanceVerifyChallenge(
      challenge: challenge,
      signature: signature,
      qrToken: qrToken,
      sessionId: sessionId,
      studentUid: studentUid,
    );
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> markPresent({
    required String qrToken,
    String? studentUid,
    String? sessionId,
    String? method,
  }) async {
    final res = await ApiClient.I.attendanceMarkPresent(
      studentUid: studentUid,
      qrToken: qrToken,
      sessionId: sessionId,
      method: method,
    );
    return Map<String, dynamic>.from(res);
  }
}
