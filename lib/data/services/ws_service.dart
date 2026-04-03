import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';

typedef WsMessageHandler = void Function(String type, Map<String, dynamic> data);

class WsService {
  static final WsService _instance = WsService._();
  factory WsService() => _instance;
  WsService._();

  WebSocketChannel? _channel;
  final _storage = const FlutterSecureStorage();
  final List<WsMessageHandler> _handlers = [];
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _intentionalClose = false;

  void addHandler(WsMessageHandler h) => _handlers.add(h);
  void removeHandler(WsMessageHandler h) => _handlers.remove(h);

  Future<void> connect() async {
    _intentionalClose = false;
    final token = await _storage.read(key: AppConstants.storageKeyToken);
    if (token == null) return;

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse('${AppConstants.wsUrl}?token=$token'),
      );
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: (e) { debugPrint('WS error: $e'); _scheduleReconnect(); },
        cancelOnError: true,
      );
      _startPing();
      debugPrint('WS connected');
    } catch (e) {
      debugPrint('WS connect error: $e');
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _intentionalClose = true;
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String? ?? '';
      final data = msg['data'] as Map<String, dynamic>? ?? msg;
      for (final h in List.of(_handlers)) { h(type, data); }
    } catch (e) {
      debugPrint('WS parse error: $e');
    }
  }

  void _onDone() {
    debugPrint('WS closed');
    _pingTimer?.cancel();
    if (!_intentionalClose) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        _channel?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {}
    });
  }
}
