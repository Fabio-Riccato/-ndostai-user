import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../../core/constants/app_constants.dart';

// ---- State ----
class AuthState {
  final UserModel? user;
  final bool loading;
  final String? error;

  const AuthState({this.user, this.loading = false, this.error});
  bool get isAuthenticated => user != null;

  // BUG FIX: error deve poter essere resettato a null esplicitamente,
  // quindi usiamo un sentinel invece di ?? che ignora il null passato.
  AuthState copyWith({UserModel? user, bool? loading, Object? error = _sentinel}) {
    return AuthState(
      user:    user    ?? this.user,
      loading: loading ?? this.loading,
      error:   error == _sentinel ? this.error : error as String?,
    );
  }
}
const Object _sentinel = Object();

// ---- Notifier ----
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _storage = const FlutterSecureStorage();
  final _api = ApiService();

  Future<bool> tryAutoLogin() async {
    final token = await _storage.read(key: AppConstants.storageKeyToken);
    if (token == null) return false;
    try {
      // BUG FIX: usa il metodo pubblico esposto da ApiService, non reflection
      final r = await _api.getMe();
      final user = UserModel.fromJson(r['user'] as Map<String, dynamic>);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      debugPrint('[AutoLogin] failed: $e');
      await _storage.delete(key: AppConstants.storageKeyToken);
      return false;
    }
  }

  Future<void> login(String email, String password, {String? deviceToken}) async {
    // BUG FIX: reset esplicito di error a null prima di ogni tentativo
    state = AuthState(loading: true);
    try {
      final r = await _api.login(email, password, deviceToken: deviceToken);
      final token = r['token'] as String;
      await _storage.write(key: AppConstants.storageKeyToken, value: token);
      final user = UserModel.fromJson(r['user'] as Map<String, dynamic>);
      state = AuthState(user: user);
    } on DioException catch (e) {
      debugPrint('[Login] DioException: ${e.type} | ${e.response?.statusCode} | ${e.response?.data} | ${e.message}');
      state = AuthState(error: _parseDioError(e));
    } catch (e) {
      debugPrint('[Login] Unexpected error: $e');
      state = AuthState(error: 'Errore imprevisto: $e');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String username,
    String? avatarPath,
  }) async {
    state = AuthState(loading: true);
    try {
      final r = await _api.register(
        email: email, password: password,
        username: username, avatarPath: avatarPath,
      );
      final token = r['token'] as String;
      await _storage.write(key: AppConstants.storageKeyToken, value: token);
      final user = UserModel.fromJson(r['user'] as Map<String, dynamic>);
      state = AuthState(user: user);
    } on DioException catch (e) {
      debugPrint('[Register] DioException: ${e.type} | ${e.response?.statusCode} | ${e.response?.data}');
      state = AuthState(error: _parseDioError(e));
    } catch (e) {
      debugPrint('[Register] Unexpected error: $e');
      state = AuthState(error: 'Errore imprevisto: $e');
    }
  }

  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    await _storage.deleteAll();
    state = const AuthState();
  }

  String _parseDioError(DioException e) {
    // Errori di rete (nessuna connessione, timeout, IP sbagliato)
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Timeout — controlla che il server sia raggiungibile';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Impossibile connettersi al server (${AppConstants.baseUrl})\nVerifica IP e firewall';
    }

    // Errori HTTP con risposta dal server
    final status = e.response?.statusCode;
    final data   = e.response?.data;
    // Estrai il messaggio di errore dal JSON del server se presente
    String? serverMsg;
    if (data is Map) serverMsg = data['error'] as String?;

    if (status == 401) return serverMsg ?? 'Credenziali non valide';
    if (status == 409) return serverMsg ?? 'Email già registrata';
    if (status == 400) return serverMsg ?? 'Dati non validi';
    if (status == 404) return 'Risorsa non trovata';
    if (status != null) return 'Errore server ($status): ${serverMsg ?? ''}';

    return 'Errore sconosciuto: ${e.message}';
  }
}

// ---- Providers ----
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
      (_) => AuthNotifier(),
);
