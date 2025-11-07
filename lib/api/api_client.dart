import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import 'endpoints.dart';

class ApiClient {
  ApiClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _accessToken;
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        if (_shouldAttemptRefresh(e)) {
          try {
            await _refreshAccessToken();
            final retryRequest = await _retry(e.requestOptions);
            return handler.resolve(retryRequest);
          } catch (_) {
            // fallthrough to original error
          }
        }
        handler.next(e);
      },
    ));
  }

  static final ApiClient _instance = ApiClient._internal();
  static ApiClient get I => _instance;

  final Dio _dio;
  final CookieJar _cookieJar = CookieJar();
  String? _accessToken;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Future<Response<T>> _retry<T>(RequestOptions requestOptions) async {
    final Options opts = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      sendTimeout: requestOptions.sendTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
    );
    return _dio.request<T>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: opts,
    );
  }

  bool _shouldAttemptRefresh(DioException e) {
    return e.response?.statusCode == 401 &&
        !_isRefreshCall(e.requestOptions.path);
  }

  bool _isRefreshCall(String path) => path.endsWith(ApiConfig.authRefresh);

  Future<void> _refreshAccessToken() async {
    final res = await _dio.post(ApiConfig.authRefresh);
    final data = res.data as Map<String, dynamic>;
    final token = data['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
    } else {
      throw DioException(
        requestOptions: RequestOptions(path: ApiConfig.authRefresh),
        response: Response(
            requestOptions: RequestOptions(path: ApiConfig.authRefresh),
            statusCode: 401),
        type: DioExceptionType.badResponse,
        error: 'Refresh failed',
      );
    }
  }

  // Auth API
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? name,
    String role = 'student',
  }) async {
    final res = await _dio.post(ApiConfig.authRegister, data: {
      'email': email,
      'password': password,
      if (name != null) 'name': name,
      'role': role,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(
      {required String email, required String password}) async {
    final res = await _dio.post(ApiConfig.authLogin, data: {
      'email': email,
      'password': password,
    });
    final map = res.data as Map<String, dynamic>;
    final token = map['accessToken'] as String?;
    if (token != null) setAccessToken(token);
    return map;
  }

  Future<void> logout() async {
    await _dio.post(ApiConfig.authLogout);
    setAccessToken(null);
    await _cookieJar.deleteAll();
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get(ApiConfig.authMe);
    return res.data as Map<String, dynamic>;
  }

  // Sessions
  Future<Map<String, dynamic>> createSession(
      {String? title, int durationMinutes = 30}) async {
    final res = await _dio.post(ApiConfig.sessions, data: {
      'title': title,
      'durationMinutes': durationMinutes,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> checkin(
      {required String sessionId,
      required String qrToken,
      required String studentUid,
      List<double>? embedding}) async {
    final res = await _dio.post(ApiConfig.sessionsCheckin, data: {
      'sessionId': sessionId,
      'qrToken': qrToken,
      'studentUid': studentUid,
      if (embedding != null) 'embedding': embedding,
    });
    return res.data as Map<String, dynamic>;
  }

  // Face
  Future<void> registerFace(
      {required String uid, required List<double> embedding}) async {
    await _dio.post(ApiConfig.faceRegister, data: {
      'uid': uid,
      'embedding': embedding,
    });
  }

  Future<Map<String, dynamic>> verifyFace(
      {required String uid, required List<double> embedding}) async {
    final res = await _dio.post(ApiConfig.faceVerify, data: {
      'uid': uid,
      'embedding': embedding,
    });
    return res.data as Map<String, dynamic>;
  }

  // Attendance
  Future<Map<String, dynamic>> attendanceBySession(String sessionId) async {
    final res = await _dio.get(ApiConfig.attendanceBySession(sessionId));
    return res.data as Map<String, dynamic>;
  }

  // Professor Sessions
  Future<Map<String, dynamic>> getProfessorSessions() async {
    final res = await _dio.get(ApiConfig.professorSessions);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSessionAttendance(String sessionId) async {
    final res = await _dio.get(ApiConfig.professorSessionAttendance(sessionId));
    return res.data as Map<String, dynamic>;
  }
}
