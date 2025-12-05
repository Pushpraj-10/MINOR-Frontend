import 'package:frontend/api/api_client.dart';

class AdminRepository {
  final ApiClient _client = ApiClient.I;

  Future<Map<String, dynamic>> fetchUsers({
    String? role,
    String? search,
    int? page,
    int? pageSize,
  }) async {
    return _client.getAdminUsers(
      role: role,
      search: search,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> updateUserRole({
    required String uid,
    required String role,
  }) async {
    return _client.updateUserRole(uid: uid, role: role);
  }

  Future<Map<String, dynamic>> fetchBiometricRequests({
    String? status,
    String? search,
    int? page,
    int? pageSize,
  }) async {
    return _client.getBiometricRequests(
      status: status,
      search: search,
      page: page,
      pageSize: pageSize,
    );
  }

  Future<void> approveBiometric(String userId) async {
    await _client.approveBiometricRequest(userId);
  }
}
