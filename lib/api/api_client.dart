import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

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
            headers: const {
              'Content-Type': 'application/json',
            },
          ),
        ) {
    _dio.interceptors.add(CookieManager(_cookieJar));

    _dio.interceptors.add(
      InterceptorsWrapper(
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
              final retried = await _retry(e.requestOptions);
              return handler.resolve(retried);
            } catch (_) {}
          }
          handler.next(e);
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          try {
            final authPresent = options.headers['Authorization'] != null;
            String bodyPreview = '';
            if (options.data != null) {
              final encoded = options.data is String
                  ? options.data as String
                  : jsonEncode(options.data);
              bodyPreview = encoded.length > 200
                  ? '${encoded.substring(0, 200)}…'
                  : encoded;
            }
            debugPrint(
                'ApiClient.request → ${options.method} ${options.path} auth=$authPresent body=$bodyPreview');
          } catch (_) {}
          handler.next(options);
        },
        onResponse: (response, handler) {
          try {
            final status = response.statusCode;
            final data = response.data;
            String dataPreview = '';
            if (data != null) {
              final encoded = data is String ? data : jsonEncode(data);
              dataPreview = encoded.length > 400
                  ? '${encoded.substring(0, 400)}…'
                  : encoded;
            }
            debugPrint(
                'ApiClient.response ← ${response.requestOptions.method} ${response.requestOptions.path} status=$status data=$dataPreview');
          } catch (_) {}
          handler.next(response);
        },
        onError: (err, handler) {
          try {
            final req = err.requestOptions;
            final status = err.response?.statusCode;
            final data = err.response?.data;
            String dataPreview = '';
            if (data != null) {
              final encoded = data is String ? data : jsonEncode(data);
              dataPreview = encoded.length > 400
                  ? '${encoded.substring(0, 400)}…'
                  : encoded;
            }
            debugPrint(
                'ApiClient.error ← ${req.method} ${req.path} status=$status data=$dataPreview');
          } catch (_) {}
          handler.next(err);
        },
      ),
    );
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
    final opts = Options(
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
    final map = res.data as Map<String, dynamic>;
    final token = map['accessToken'] as String?;
    if (token != null && token.isNotEmpty) {
      _accessToken = token;
    } else {
      throw DioException(
        requestOptions: RequestOptions(path: ApiConfig.authRefresh),
        response: Response(
          requestOptions: RequestOptions(path: ApiConfig.authRefresh),
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
        error: 'Refresh failed',
      );
    }
  }

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
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(ApiConfig.authLogin, data: {
      'email': email,
      'password': password,
    });
    final map = Map<String, dynamic>.from(res.data as Map);
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
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createSession({
    String? title,
    int durationMinutes = 30,
  }) async {
    final res = await _dio.post(ApiConfig.sessions, data: {
      'title': title,
      'durationMinutes': durationMinutes,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> checkin({
    required String sessionId,
    required String qrToken,
    required String studentUid,
    List<double>? embedding,
    String? method,
    String? challenge,
    String? signature,
  }) async {
    final body = {
      'sessionId': sessionId,
      'qrToken': qrToken,
      'studentUid': studentUid,
    };
    if (embedding != null) body['embedding'] = embedding as String;
    if (method != null) body['method'] = method;
    if (challenge != null) body['challenge'] = challenge;
    if (signature != null) body['signature'] = signature;

    final res = await _dio.post(ApiConfig.sessionsCheckin, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> registerBiometricKey({required String publicKeyPem}) async {
    debugPrint(
        'ApiClient.registerBiometricKey: pemLength=${publicKeyPem.length}');
    try {
      final res = await _dio.post(
        ApiConfig.biometricsRegisterKey,
        data: {'publicKeyPem': publicKeyPem},
      );
      debugPrint('ApiClient.registerBiometricKey: status=${res.statusCode}');
    } catch (err) {
      if (err is DioException) {
        debugPrint(
            'ApiClient.registerBiometricKey Dio error: status=${err.response?.statusCode} data=${err.response?.data}');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> biometricCheck() async {
    final res = await _dio.get(ApiConfig.biometricsCheck);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> attendanceVerifyChallenge({
    required String challenge,
    required String signature,
    String? qrToken,
    String? sessionId,
    String? studentUid,
  }) async {
    final body = {
      'challenge': challenge,
      'signature': signature,
    };
    if (qrToken != null) body['qrToken'] = qrToken;
    if (sessionId != null) body['sessionId'] = sessionId;
    if (studentUid != null) body['studentUid'] = studentUid;

    final res =
        await _dio.post(ApiConfig.attendanceVerifyChallenge, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> attendanceMarkPresent({
    required String? qrToken,
    String? studentUid,
    String? sessionId,
    String? method,
  }) async {
    final body = {};
    if (studentUid != null) body['studentUid'] = studentUid;
    if (qrToken != null) body['qrToken'] = qrToken;
    if (sessionId != null) body['sessionId'] = sessionId;
    if (method != null) body['method'] = method;

    final res = await _dio.post(ApiConfig.attendanceMarkPresent, data: body);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> attendanceBySession(String sessionId) async {
    final res = await _dio.get(ApiConfig.attendanceBySession(sessionId));
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getProfessorSessions() async {
    final res = await _dio.get(ApiConfig.professorSessions);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> getSessionAttendance(String sessionId) async {
    final res = await _dio.get(ApiConfig.professorSessionAttendance(sessionId));
    return Map<String, dynamic>.from(res.data as Map);
  }
}
