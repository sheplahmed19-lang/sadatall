import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin wrapper around a single Socket.io connection to the backend's chat
/// namespace (see backend/src/sockets/index.js). One instance is shared by
/// a whole mode's ChatRepository — connecting once per app session rather
/// than per chat screen, since the server tracks "online" purely by an
/// active socket connection existing.
class ChatSocketClient {
  ChatSocketClient({required String baseUrl, required Future<String?> Function() getToken})
      : _socketBaseUrl = _stripApiSuffix(baseUrl),
        _getToken = getToken;

  final String _socketBaseUrl;
  final Future<String?> Function() _getToken;

  io.Socket? _socket;
  bool _connecting = false;

  final _newMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _threadUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedController = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get newMessages => _newMessageController.stream;
  Stream<Map<String, dynamic>> get threadUpdates => _threadUpdatedController.stream;
  Stream<Map<String, dynamic>> get typingEvents => _typingController.stream;
  Stream<Map<String, dynamic>> get presenceEvents => _presenceController.stream;

  /// Fires on every successful (re)connection — the socket layer's way of
  /// saying "the backend is reachable again", used to retry queued
  /// outbound messages instead of waiting for the user to reopen the chat.
  Stream<void> get connected => _connectedController.stream;

  static String _stripApiSuffix(String baseUrl) {
    var url = baseUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.endsWith('/api')) url = url.substring(0, url.length - 4);
    return url;
  }

  Future<void> ensureConnected() async {
    if (_socket?.connected == true || _connecting) return;
    _connecting = true;
    try {
      final token = await _getToken();
      if (token == null) return;

      _socket?.dispose();
      _socket = io.io(
        _socketBaseUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .enableReconnection()
            .disableAutoConnect()
            .build(),
      );

      _socket!
        ..onConnect((_) {
          debugPrint('[chat socket] connected');
          _connectedController.add(null);
        })
        ..onConnectError((e) => debugPrint('[chat socket] connect error: $e'))
        ..onDisconnect((_) => debugPrint('[chat socket] disconnected'))
        ..on('new_message', (data) {
          if (data is Map) _newMessageController.add(Map<String, dynamic>.from(data));
        })
        ..on('thread_updated', (data) {
          if (data is Map) _threadUpdatedController.add(Map<String, dynamic>.from(data));
        })
        ..on('typing', (data) {
          if (data is Map) _typingController.add(Map<String, dynamic>.from(data));
        })
        ..on('presence', (data) {
          if (data is Map) _presenceController.add(Map<String, dynamic>.from(data));
        })
        ..connect();
    } finally {
      _connecting = false;
    }
  }

  void joinChat(String chatId) {
    _socket?.emit('join_chat', {'chatId': chatId});
  }

  void leaveChat(String chatId) {
    _socket?.emit('leave_chat', {'chatId': chatId});
  }

  void emitTyping(String chatId) {
    _socket?.emit('typing', {'chatId': chatId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
