import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Central HTTP client for all chat service API calls.
class ApiService {
  ApiService._();

  static late Dio _dio;
  static String _baseUrl = '';

  static void configure({required String baseUrl}) {
    _baseUrl = baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth interceptor — injects JWT on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AuthService.instance.currentToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('[ApiService] Error: ${error.response?.statusCode} '
            '${error.requestOptions.path}');
        handler.next(error);
      },
    ));
  }

  static Dio get client => _dio;
  static String get baseUrl => _baseUrl;

  // ── Threads ──────────────────────────────────────────────────────────────

  static Future<Response> getThreads() =>
      _dio.get('/chat/threads');

  static Future<Response> createThread(Map<String, dynamic> body) =>
      _dio.post('/chat/threads', data: body);

  static Future<Response> getMessages(String threadId, {int page = 1}) =>
      _dio.get('/chat/threads/$threadId/messages',
          queryParameters: {'page': page, 'limit': 30});

  // ── Messages ─────────────────────────────────────────────────────────────

  static Future<Response> sendMessage(Map<String, dynamic> body) =>
      _dio.post('/chat/messages', data: body);

  static Future<Response> editMessage(String messageId, String content) =>
      _dio.put('/chat/messages/$messageId', data: {'content': content});

  static Future<Response> markSeen(String messageId) =>
      _dio.put('/chat/messages/$messageId/read');

  // ── Broadcast ─────────────────────────────────────────────────────────────

  static Future<Response> sendBroadcast(Map<String, dynamic> body) =>
      _dio.post('/chat/broadcast', data: body);

  static Future<Response> getBroadcast(String broadcastId) =>
      _dio.get('/chat/broadcast/$broadcastId');

  // ── Search ────────────────────────────────────────────────────────────────

  static Future<Response> globalSearch(String query) =>
      _dio.get('/chat/search', queryParameters: {'q': query, 'scope': 'global'});

  static Future<Response> threadSearch(String threadId, String query) =>
      _dio.get('/chat/search',
          queryParameters: {'q': query, 'thread_id': threadId});

  static Future<Response> searchByRollNumber(String rollNumber) =>
      _dio.get('/students/search',
          queryParameters: {'roll_number': rollNumber});

  // ── Status ────────────────────────────────────────────────────────────────

  static Future<Response> heartbeat() =>
      _dio.put('/chat/status/heartbeat');

  static Future<Response> getUserStatus(String userId) =>
      _dio.get('/chat/status/$userId');

  // ── Mute ──────────────────────────────────────────────────────────────────

  static Future<Response> muteThread(String threadId, bool mute) =>
      _dio.put('/chat/threads/$threadId/mute', data: {'muted': mute});

  static Future<Response> muteAll(bool mute) =>
      _dio.put('/chat/settings/mute-all', data: {'muted': mute});

  // ── Children (parent) ─────────────────────────────────────────────────────

  static Future<Response> getChildren() =>
      _dio.get('/chat/children');

  static Future<Response> getTeachersForChild(String studentId) =>
      _dio.get('/chat/teachers', queryParameters: {'student_id': studentId});

  // ── Student auth ──────────────────────────────────────────────────────────

  static Future<Response> requestStudentOtp(String studentId) =>
      _dio.post('/auth/student/request-otp', data: {'student_id': studentId});

  static Future<Response> verifyStudentOtp(String studentId, String otp) =>
      _dio.post('/auth/student/verify-otp',
          data: {'student_id': studentId, 'otp': otp});

  // ── Student teachers ──────────────────────────────────────────────────────

  static Future<Response> getStudentTeachers() =>
      _dio.get('/chat/student/teachers');

  // ── Unread count ──────────────────────────────────────────────────────────

  static Future<Response> getUnreadCount() =>
      _dio.get('/chat/unread-count');

  // ── User context (all roles) ──────────────────────────────────────────────────

  /// Fetches the full resolved user context for the currently authenticated user.
  /// Called by the splash screen after login to hydrate the client-side auth state.
  static Future<Response> getMe() =>
      _dio.get('/chat/me');

  // ── Device token ──────────────────────────────────────────────────────────

  static Future<Response> registerDeviceToken(
          String deviceToken, String platform) =>
      _dio.post('/chat/device-token',
          data: {'device_token': deviceToken, 'device_platform': platform});

  // ── Dev / test token (development only) ───────────────────────────────────

  static Future<Response> getTestToken(Map<String, dynamic> body) =>
      _dio.post('/dev/auth/test-token', data: body);
}
