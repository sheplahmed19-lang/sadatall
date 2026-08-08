import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_thread.dart';
import 'chat_api_client.dart';
import 'chat_outbox_store.dart';
import 'chat_socket_client.dart';

/// Absolute creation-order key for sorting messages — the database's own
/// strictly-increasing auto-increment id, not any timestamp. Immune to
/// device/server clock skew or timezone formatting entirely, unlike
/// sorting on `sentAt`. A local/pending message (id like "local_<uuid>",
/// no real server id yet) sorts using its local creation time instead,
/// scaled into a range far above any real database id — pending messages
/// are always the newest thing in the chat by definition, so this keeps
/// them at the top until the server confirms and assigns the real id.
BigInt _messageSortKey(ChatMessage m) {
  final idAsInt = BigInt.tryParse(m.id);
  if (idAsInt != null) return idAsInt;
  final micros = (m.sentAt ?? DateTime.now()).microsecondsSinceEpoch;
  return BigInt.from(micros);
}

/// Order lifecycle statuses that gate order-scoped chats, mirrored from the
/// backend's shared Order status constants.
class OrderChatTrigger {
  static const String opensOn = 'ACCEPTED_BY_CAPTAIN';
  static const String closesOn = 'DELIVERED';
}

/// Backend REST + Socket.io data layer for the chat feature (Postgres-backed
/// — see backend/src/services/chatService.js). One instance per mode,
/// shared across every chat screen in that mode so the underlying socket
/// connection is opened once per app session, not once per screen.
///
/// Outgoing messages are queued to a local outbox first and shown
/// immediately as a "sending" placeholder — sendXMessage() never throws.
/// If the network call fails, the placeholder stays visible flagged
/// "failed" (needs a connection) and is retried automatically on the next
/// socket reconnect, or manually via [retryFailed].
class ChatRepository {
  ChatRepository({required this.api, required this.socket, ChatOutboxStore? outbox})
      : _outbox = outbox ?? ChatOutboxStore() {
    _reconnectSub = socket.connected.listen((_) => _retryAllFailed());
  }

  final ChatApiClient api;
  final ChatSocketClient socket;
  final ChatOutboxStore _outbox;
  final _uuid = const Uuid();
  final _outboxChanged = StreamController<String>.broadcast();
  StreamSubscription<void>? _reconnectSub;

  void dispose() {
    _reconnectSub?.cancel();
  }

  // ── thread lookup / lazy creation ────────────────────────────────────────

  Future<ChatThread> getOrCreateSupportChat(ChatParticipant self) async {
    await socket.ensureConnected();
    final json = await api.post('/chats/support');
    return ChatThread.fromJson(json);
  }

  Future<ChatThread> getOrCreateOrderChat({
    required String orderId,
    required ChatParticipant self,
    required ChatParticipant other,
    required bool isVendorSide,
    String? orderStatus,
  }) async {
    await socket.ensureConnected();
    final json = await api.post('/chats/order', body: {
      'orderId': orderId,
      'isVendorSide': isVendorSide,
      'otherRole': other.role.name,
      'otherId': other.id,
      if (orderStatus != null) 'orderStatus': orderStatus,
    });
    return ChatThread.fromJson(json);
  }

  // ── streams ───────────────────────────────────────────────────────────────

  /// Full message list for a chat, newest first — re-emits on every
  /// new_message socket event and on every outbox change (queued, sent,
  /// failed, retried), merging in any not-yet-confirmed outgoing messages
  /// for this chat as optimistic placeholders.
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 200}) {
    late StreamController<List<ChatMessage>> controller;
    StreamSubscription? sub;
    StreamSubscription<String>? outboxSub;
    final byId = <String, ChatMessage>{};
    final outboxKeys = <String>{};

    void emit() {
      final list = byId.values.toList()
        ..sort((a, b) => _messageSortKey(b).compareTo(_messageSortKey(a)));
      if (!controller.isClosed) controller.add(list);
    }

    Future<void> refreshOutbox() async {
      for (final key in outboxKeys) {
        byId.remove(key);
      }
      outboxKeys.clear();
      final pending = await _outbox.forChat(chatId);
      for (final m in pending) {
        final chatMessage = m.toChatMessage();
        byId[chatMessage.id] = chatMessage;
        outboxKeys.add(chatMessage.id);
      }
      emit();
    }

    controller = StreamController<List<ChatMessage>>.broadcast(
      onListen: () async {
        socket.joinChat(chatId);
        sub = socket.newMessages.listen((data) {
          if (data['chatId'] != chatId) return;
          final message = ChatMessage.fromJson(Map<String, dynamic>.from(data['message'] as Map));
          byId[message.id] = message;
          emit();
        });
        outboxSub = _outboxChanged.stream.where((id) => id == chatId).listen((_) => refreshOutbox());
        await refreshOutbox();
        try {
          final json = await api.get('/chats/$chatId/messages', query: {'limit': limit.toString()});
          final list = (json['messages'] as List).map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)));
          for (final m in list) {
            byId[m.id] = m;
          }
          emit();
        } catch (_) {
          // Leave the stream open — a later socket event or retry can still
          // populate it; the UI shows a spinner until the first emit.
        }
      },
      onCancel: () {
        sub?.cancel();
        outboxSub?.cancel();
        socket.leaveChat(chatId);
      },
    );
    return controller.stream;
  }

  /// All threads the current user is a participant in, newest activity
  /// first.
  Stream<List<ChatThread>> streamThreadsFor(String participantId) {
    late StreamController<List<ChatThread>> controller;
    StreamSubscription? threadSub;
    StreamSubscription? messageSub;
    final byId = <String, ChatThread>{};

    void emit() {
      final list = byId.values.toList()
        ..sort((a, b) => (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
      if (!controller.isClosed) controller.add(list);
    }

    Future<void> refresh() async {
      try {
        final json = await api.get('/chats');
        final list = (json['threads'] as List).map((t) => ChatThread.fromJson(Map<String, dynamic>.from(t as Map)));
        byId.clear();
        for (final t in list) {
          byId[t.id] = t;
        }
        emit();
      } catch (_) {}
    }

    controller = StreamController<List<ChatThread>>.broadcast(
      onListen: () async {
        await socket.ensureConnected();
        threadSub = socket.threadUpdates.listen((_) => refresh());
        // A brand-new chat's first message also means a brand-new thread
        // this participant may not have in `byId` yet — cheapest correct
        // fix is just re-fetching the list rather than tracking creation
        // separately.
        messageSub = socket.newMessages.listen((_) => refresh());
        await refresh();
      },
      onCancel: () {
        threadSub?.cancel();
        messageSub?.cancel();
      },
    );
    return controller.stream;
  }

  // ── sending ───────────────────────────────────────────────────────────────
  //
  // Every sendXMessage() below queues the message to the local outbox and
  // returns once that's done — it does not wait on (or throw from) the
  // network call, so the caller can treat "sent" as "queued, appears in the
  // UI now" and never needs its own try/catch around network failures.

  Future<void> sendTextMessage({
    required String chatId,
    required ChatParticipant sender,
    required String text,
  }) {
    return _queue(OutboxMessage(
      clientMessageId: _uuid.v4(),
      chatId: chatId,
      senderId: sender.participantId,
      senderRole: sender.role,
      type: 'text',
      text: text,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> sendAttachmentMessage({
    required String chatId,
    required ChatParticipant sender,
    required MessageType type,
    required String attachmentKey,
    String? attachmentUrl,
    String? caption,
  }) {
    return _queue(OutboxMessage(
      clientMessageId: _uuid.v4(),
      chatId: chatId,
      senderId: sender.participantId,
      senderRole: sender.role,
      type: messageTypeToString(type),
      text: caption,
      attachmentKey: attachmentKey,
      attachmentUrl: attachmentUrl,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> sendLocationMessage({
    required String chatId,
    required ChatParticipant sender,
    required double lat,
    required double lng,
  }) {
    return _queue(OutboxMessage(
      clientMessageId: _uuid.v4(),
      chatId: chatId,
      senderId: sender.participantId,
      senderRole: sender.role,
      type: 'location',
      locationLat: lat,
      locationLng: lng,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> sendOrderRefMessage({
    required String chatId,
    required ChatParticipant sender,
    required OrderRef orderRef,
  }) {
    return _queue(OutboxMessage(
      clientMessageId: _uuid.v4(),
      chatId: chatId,
      senderId: sender.participantId,
      senderRole: sender.role,
      type: 'order_ref',
      orderRefOrderId: orderRef.orderId,
      orderRefOrderNumber: orderRef.orderNumber,
      orderRefStatusSnapshot: orderRef.statusSnapshot,
      createdAt: DateTime.now(),
    ));
  }

  /// Re-attempts a specific failed message — wired to a tap on its "needs
  /// internet" indicator.
  Future<void> retryFailed(String chatId, String clientMessageId) async {
    final pending = await _outbox.forChat(chatId);
    for (final m in pending) {
      if (m.clientMessageId == clientMessageId) {
        await _attemptSend(m);
        return;
      }
    }
  }

  /// Drops a failed message without retrying — the only "delete" available
  /// for a message that never reached the server.
  Future<void> discardFailed(String chatId, String clientMessageId) async {
    await _outbox.remove(clientMessageId);
    _outboxChanged.add(chatId);
  }

  Future<void> _retryAllFailed() async {
    final all = await _outbox.loadAll();
    for (final m in all.where((m) => m.failed)) {
      await _attemptSend(m);
    }
  }

  Future<void> _queue(OutboxMessage message) async {
    await _outbox.upsert(message);
    _outboxChanged.add(message.chatId);
    await _attemptSend(message);
  }

  Future<void> _attemptSend(OutboxMessage message) async {
    try {
      await api.post('/chats/${message.chatId}/messages', body: message.toRequestBody());
      await _outbox.remove(message.clientMessageId);
    } catch (_) {
      // No internet / backend unreachable / timed out — keep it queued and
      // flagged so the UI shows "needs internet"; a later reconnect or
      // manual retry will re-attempt with the same clientMessageId, which
      // the backend treats idempotently so it can never land twice.
      await _outbox.upsert(message.copyWith(failed: true));
    } finally {
      _outboxChanged.add(message.chatId);
    }
  }

  // ── read receipts / typing ──────────────────────────────────────────────

  /// Marks every message in the chat read up to now for [participantId].
  /// Per-message read state is derived server-side from this timestamp, so
  /// there's no separate "mark these message ids read" call needed anymore.
  Future<void> markThreadRead(String chatId, String participantId) => api.put('/chats/$chatId/read');

  Future<void> softDeleteMessage(String chatId, String messageId) => api.delete('/chats/$chatId/messages/$messageId');
}
