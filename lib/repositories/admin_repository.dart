import 'package:frontend/api/api_client.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<Map<String, dynamic>> bulkPreviewUsers({required PlatformFile file}) {
    return _client.adminBulkPreviewUsers(
      fileName: file.name,
      filePath: file.path,
      bytes: file.bytes,
    );
  }

  Future<Map<String, dynamic>> bulkImportUsers({
    required String uploadId,
    required Map<String, String> mapping,
  }) {
    return _client.adminBulkImportUsers(uploadId: uploadId, mapping: mapping);
  }
}
