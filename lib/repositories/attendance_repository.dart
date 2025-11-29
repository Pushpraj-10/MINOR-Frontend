import 'package:frontend/api/api_client.dart';

class AttendanceRepository {
  /// GET /biometrics/check
  /// -> { status: 'none'|'pending'|'approved'|'revoked', publicKeyHash?: string, challenge?: string }
  Future<Map<String, dynamic>> checkKey() async {
    final res = await ApiClient.I.biometricCheck();
    return Map<String, dynamic>.from(res);
  }

  /// POST /biometrics/register-key
  Future<void> registerKey({required String publicKeyPem}) async {
    await ApiClient.I.registerBiometricKey(publicKeyPem: publicKeyPem);
  }

  /// POST /attendance/verify-challenge
  /// -> { verified: bool, biometricChanged?: bool, reason?: string }
  Future<Map<String, dynamic>> verifyChallenge({
    required String challenge,
    required String signature,
    required String qrToken,
    String? sessionId,
  }) async {
    final res = await ApiClient.I.attendanceVerifyChallenge(
      challenge: challenge,
      signature: signature,
      qrToken: qrToken,
      sessionId: sessionId,
    );
    return Map<String, dynamic>.from(res);
  }

  /// POST /attendance/mark-present
  /// -> server-specific shape (assume { ok: true, ... })
  Future<Map<String, dynamic>> markPresent({
    required String qrToken,
    String? studentUid,
    String? sessionId,
  }) async {
    final res = await ApiClient.I.attendanceMarkPresent(
      studentUid: studentUid,
      qrToken: qrToken,
      sessionId: sessionId,
    );
    return Map<String, dynamic>.from(res);
  }
}
