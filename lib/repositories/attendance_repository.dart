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
    String? challenge,
    String? signature,
  }) async {
    final res = await ApiClient.I.attendanceMarkPresent(
      studentUid: studentUid,
      qrToken: qrToken,
      sessionId: sessionId,
      method: method,
      challenge: challenge,
      signature: signature,
    );
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> studentAttendanceRecords({
    required String userId,
    int? limit,
    int? skip,
  }) async {
    final res = await ApiClient.I.getStudentAttendanceRecords(
      userId: userId,
      limit: limit,
      skip: skip,
    );
    return res;
  }

  Future<List<Map<String, dynamic>>> listLeaves({String status = 'pending'}) {
    return ApiClient.I.listAllLeaves(status: status == 'all' ? null : status);
  }

  Future<Map<String, dynamic>> reviewLeave({
    required String leaveId,
    required String decision,
    String? note,
  }) {
    return ApiClient.I
        .reviewLeave(leaveId: leaveId, status: decision, note: note);
  }

  Future<List<Map<String, dynamic>>> studentsByBatch(
      {String? search, int? limit}) {
    return ApiClient.I.getStudentsByBatch(search: search, limit: limit);
  }
}
