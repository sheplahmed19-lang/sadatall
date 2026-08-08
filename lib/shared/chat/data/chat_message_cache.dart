import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Caches each chat's last-known message list (raw wire-format JSON, same
/// shape the REST/socket APIs already use) locally, so opening a chat shows
/// its recent history immediately — even fully offline — instead of an
/// empty/loading screen until the network responds. Overwritten with
/// whatever's freshest every time the REST fetch succeeds or a live socket
/// message arrives.
class ChatMessageCache {
  static String _key(String chatId) => 'chat_message_cache_$chatId';

  Future<List<Map<String, dynamic>>> load(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(chatId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(String chatId, List<Map<String, dynamic>> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(chatId), jsonEncode(messages));
  }
}
