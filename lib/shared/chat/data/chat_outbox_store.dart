import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';

/// A message queued for sending, persisted locally so it survives app
/// restarts while offline. Rendered as an optimistic placeholder in the
/// chat until the real send succeeds (removed) or is confirmed failed
/// (kept, flagged, retried on reconnect or manual tap).
class OutboxMessage {
  final String clientMessageId;
  final String chatId;
  final String senderId;
  final ChatRole senderRole;
  final String type;
  final String? text;
  final String? attachmentKey;
  final String? attachmentUrl;
  final double? locationLat;
  final double? locationLng;
  final String? orderRefOrderId;
  final String? orderRefOrderNumber;
  final String? orderRefStatusSnapshot;
  final DateTime createdAt;
  final bool failed;

  const OutboxMessage({
    required this.clientMessageId,
    required this.chatId,
    required this.senderId,
    required this.senderRole,
    required this.type,
    this.text,
    this.attachmentKey,
    this.attachmentUrl,
    this.locationLat,
    this.locationLng,
    this.orderRefOrderId,
    this.orderRefOrderNumber,
    this.orderRefStatusSnapshot,
    required this.createdAt,
    this.failed = false,
  });

  OutboxMessage copyWith({bool? failed}) => OutboxMessage(
        clientMessageId: clientMessageId,
        chatId: chatId,
        senderId: senderId,
        senderRole: senderRole,
        type: type,
        text: text,
        attachmentKey: attachmentKey,
        attachmentUrl: attachmentUrl,
        locationLat: locationLat,
        locationLng: locationLng,
        orderRefOrderId: orderRefOrderId,
        orderRefOrderNumber: orderRefOrderNumber,
        orderRefStatusSnapshot: orderRefStatusSnapshot,
        createdAt: createdAt,
        failed: failed ?? this.failed,
      );

  /// Optimistic placeholder shown in the message list until reconciled.
  ChatMessage toChatMessage() => ChatMessage(
        id: 'local_$clientMessageId',
        senderId: senderId,
        senderRole: senderRole,
        type: messageTypeFromString(type),
        text: text,
        attachmentKey: attachmentKey,
        attachmentUrl: attachmentUrl,
        location: locationLat == null ? null : ChatLocation(lat: locationLat!, lng: locationLng!),
        orderRef: orderRefOrderId == null
            ? null
            : OrderRef(
                orderId: orderRefOrderId!,
                orderNumber: orderRefOrderNumber ?? '',
                statusSnapshot: orderRefStatusSnapshot ?? '',
              ),
        sentAt: createdAt,
        clientMessageId: clientMessageId,
        deliveryStatus: failed ? MessageDeliveryStatus.failed : MessageDeliveryStatus.sending,
      );

  /// Rebuilds the exact REST body sendMessage() would have posted, for retry.
  Map<String, dynamic> toRequestBody() => {
        'type': type,
        if (text != null) 'text': text,
        if (attachmentKey != null) 'attachmentKey': attachmentKey,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        if (locationLat != null) 'location': {'lat': locationLat, 'lng': locationLng},
        if (orderRefOrderId != null)
          'orderRef': {
            'orderId': orderRefOrderId,
            'orderNumber': orderRefOrderNumber,
            'statusSnapshot': orderRefStatusSnapshot,
          },
        'clientMessageId': clientMessageId,
      };

  Map<String, dynamic> _toStorageJson() => {
        'clientMessageId': clientMessageId,
        'chatId': chatId,
        'senderId': senderId,
        'senderRole': senderRole.name,
        'type': type,
        'text': text,
        'attachmentKey': attachmentKey,
        'attachmentUrl': attachmentUrl,
        'locationLat': locationLat,
        'locationLng': locationLng,
        'orderRefOrderId': orderRefOrderId,
        'orderRefOrderNumber': orderRefOrderNumber,
        'orderRefStatusSnapshot': orderRefStatusSnapshot,
        'createdAt': createdAt.toIso8601String(),
        'failed': failed,
      };

  static OutboxMessage _fromStorageJson(Map<String, dynamic> json) => OutboxMessage(
        clientMessageId: json['clientMessageId'] as String,
        chatId: json['chatId'] as String,
        senderId: json['senderId'] as String,
        senderRole: chatRoleFromString(json['senderRole'] as String? ?? 'user'),
        type: json['type'] as String,
        text: json['text'] as String?,
        attachmentKey: json['attachmentKey'] as String?,
        attachmentUrl: json['attachmentUrl'] as String?,
        locationLat: (json['locationLat'] as num?)?.toDouble(),
        locationLng: (json['locationLng'] as num?)?.toDouble(),
        orderRefOrderId: json['orderRefOrderId'] as String?,
        orderRefOrderNumber: json['orderRefOrderNumber'] as String?,
        orderRefStatusSnapshot: json['orderRefStatusSnapshot'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        failed: json['failed'] as bool? ?? false,
      );

  static List<OutboxMessage> listFromJson(String raw) {
    if (raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => _fromStorageJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<OutboxMessage> messages) =>
      jsonEncode(messages.map((m) => m._toStorageJson()).toList());
}

/// Persists queued outbound chat messages across every mode/chat in a single
/// SharedPreferences entry — the outbox is expected to stay tiny (only
/// messages currently sending or that failed and are awaiting retry), so a
/// flat JSON blob is simpler and just as reliable as a real database here.
class ChatOutboxStore {
  static const _prefsKey = 'chat_outbox_v1';

  Future<List<OutboxMessage>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return OutboxMessage.listFromJson(prefs.getString(_prefsKey) ?? '');
  }

  Future<List<OutboxMessage>> forChat(String chatId) async {
    final all = await loadAll();
    return all.where((m) => m.chatId == chatId).toList();
  }

  Future<void> upsert(OutboxMessage message) async {
    final all = await loadAll();
    final index = all.indexWhere((m) => m.clientMessageId == message.clientMessageId);
    if (index >= 0) {
      all[index] = message;
    } else {
      all.add(message);
    }
    await _save(all);
  }

  Future<void> remove(String clientMessageId) async {
    final all = await loadAll();
    all.removeWhere((m) => m.clientMessageId == clientMessageId);
    await _save(all);
  }

  Future<void> _save(List<OutboxMessage> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, OutboxMessage.listToJson(all));
  }
}
