import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._();
  factory ApiService() => _instance;
  ApiService._() { _setupDio(); }

  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  void _setupDio() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Logga ogni richiesta/risposta nel terminale (visibile con flutter run)
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      requestHeader: false,
      responseHeader: false,
      error: true,
      logPrint: (o) => debugPrint('[DIO] $o'),
    ));

    // Auth interceptor — aggiunge Bearer token se presente
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.storageKeyToken);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (e, handler) {
        // Propaga l'errore senza inghiottirlo
        handler.next(e);
      },
    ));
  }

  // ---- Auth ----

  /// Profilo utente corrente — usato per auto-login al posto di getDio() via reflection
  Future<Map<String, dynamic>> getMe() async {
    final r = await _dio.get('/api/users/me');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    String? avatarPath,
  }) async {
    final formData = FormData.fromMap({
      'email': email,
      'password': password,
      'username': username,
      if (avatarPath != null)
        'avatar': await MultipartFile.fromFile(avatarPath, filename: 'avatar.jpg'),
    });
    final r = await _dio.post('/api/auth/register', data: formData);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login(String email, String password, {String? deviceToken}) async {
    final r = await _dio.post('/api/auth/login', data: {
      'email': email, 'password': password, if (deviceToken != null) 'deviceToken': deviceToken,
    });
    return r.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    await _dio.post('/api/auth/logout');
  }

  Future<Map<String, dynamic>> updateAccount({String? username, String? avatarUrl}) async {
    final r = await _dio.patch('/api/auth/account', data: {
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    });
    return r.data as Map<String, dynamic>;
  }

  // ---- Circles ----
  Future<Map<String, dynamic>> createCircle(String name) async {
    final r = await _dio.post('/api/circles', data: {'name': name});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinCircle(String inviteCode) async {
    final r = await _dio.post('/api/circles/join', data: {'inviteCode': inviteCode});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getUserCircles() async {
    final r = await _dio.get('/api/circles');
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCircleMembers(String circleId) async {
    final r = await _dio.get('/api/circles/$circleId/members');
    return r.data as Map<String, dynamic>;
  }

  Future<void> removeMember(String circleId, String userId) async {
    await _dio.delete('/api/circles/$circleId/members/$userId');
  }

  Future<void> updateCircleSettings(String circleId, Map<String, dynamic> settings) async {
    await _dio.patch('/api/circles/$circleId/settings', data: settings);
  }

  // ---- Location ----
  Future<void> updateLocation(Map<String, dynamic> data) async {
    await _dio.post('/api/location/update', data: data);
  }

  Future<void> markOffline() async {
    try { await _dio.post('/api/location/offline'); } catch (_) {}
  }

  Future<Map<String, dynamic>> getLocationHistory(String userId, String circleId) async {
    final r = await _dio.get('/api/location/history/$userId', queryParameters: {'circleId': circleId});
    return r.data as Map<String, dynamic>;
  }

  // ---- Places ----
  Future<Map<String, dynamic>> getPlaces(String circleId) async {
    final r = await _dio.get('/api/places', queryParameters: {'circleId': circleId});
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createPlace(Map<String, dynamic> data) async {
    final r = await _dio.post('/api/places', data: data);
    return r.data as Map<String, dynamic>;
  }

  Future<void> deletePlace(String placeId) async {
    await _dio.delete('/api/places/$placeId');
  }

  // ---- Driving ----
  Future<Map<String, dynamic>> getDrivingReports(String circleId) async {
    final r = await _dio.get('/api/driving/reports', queryParameters: {'circleId': circleId});
    return r.data as Map<String, dynamic>;
  }

  Future<void> reportPhoneUse() async {
    try { await _dio.post('/api/driving/phone-use'); } catch (_) {}
  }

  // ---- Users ----
  Future<void> updateDeviceToken(String token) async {
    await _dio.patch('/api/users/device-token', data: {'deviceToken': token});
  }
}