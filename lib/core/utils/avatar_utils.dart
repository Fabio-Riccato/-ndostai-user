import '../constants/app_constants.dart';

/// Converte un avatar URL relativo in assoluto.
/// "/uploads/avatar_123.webp" → "http://192.168.x.x:3000/uploads/avatar_123.webp"
/// "https://..." → invariato
/// null / "" → null
String? resolveAvatarUrl(String? url) {
  if (url == null || url.trim().isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  final base = AppConstants.baseUrl.endsWith('/')
      ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
      : AppConstants.baseUrl;
  final p = url.startsWith('/') ? url : '/$url';
  return '$base$p';
}