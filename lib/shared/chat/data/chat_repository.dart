import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_thread.dart';
import 'chat_api_client.dart';
import 'chat_message_cache.dart';
import 'chat_outbox_store.dart';
import 'chat_socket_client.dart';

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
  ChatRepository({required this.api, required this.socket, ChatOutboxStore? outbox, ChatMessageCache? cache})
      : _outbox = outbox ?? ChatOutboxStore(),
        _cache = cache ?? ChatMessageCache() {
    _reconnectSub = socket.connected.listen((_) => _retryAllFailed());
  }

  final ChatApiClient api;
  final ChatSocketClient socket;
  final ChatOutboxStore _outbox;
  final ChatMessageCache _cache;
  final _uuid = const Uuid();
  final _outboxChanged = StreamController<String>.broadcast();

  /// Messages the server confirmed in a send response, keyed by chatId.
  /// Feeds the same path as an incoming socket event so a sent message is
  /// never momentarily absent from the list: the outbox placeholder is only
  /// dropped once its confirmed replacement has already been merged in.
  /// Without this the message vanished between the POST returning and the
  /// `new_message` echo arriving — indefinitely, if the socket was down.
  final _sentMessages = StreamController<({String chatId, Map<String, dynamic> raw})>.broadcast();
  StreamSubscription<void>? _reconnectSub;

  void dispose() {
    _reconnectSub?.cancel();
    _outboxChanged.close();
    _sentMessages.close();
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
    StreamSubscription<({String chatId, Map<String, dynamic> raw})>? sentSub;
    StreamSubscription<void>? reconnectSub;
    final byId = <String, ChatMessage>{};
    final outboxKeys = <String>{};
    // Raw wire-format JSON per message, kept alongside `byId` purely so the
    // on-disk cache can be persisted without needing a ChatMessage.toJson().
    final rawById = <String, Map<String, dynamic>>{};

    void emit() {
      final list = byId.values.toList()
        ..sort((a, b) => (b.sentAt ?? DateTime(0)).compareTo(a.sentAt ?? DateTime(0)));
      if (!controller.isClosed) controller.add(list);
    }

    Future<void> persistCache() => _cache.save(chatId, rawById.values.toList());

    Future<void> loadCache() async {
      final cached = await _cache.load(chatId);
      for (final raw in cached) {
        final id = raw['id'] as String?;
        if (id == null) continue;
        try {
          byId[id] = ChatMessage.fromJson(raw);
          rawById[id] = raw;
        } catch (_) {}
      }
      emit();
    }

    Future<void> refreshOutbox() async {
      // Read first, then swap. Clearing byId before the await left a window
      // where any concurrent emit() (a socket event, a confirmed send)
      // rendered the list without the still-pending placeholders, making a
      // just-typed message blink out.
      final pending = await _outbox.forChat(chatId);
      for (final key in outboxKeys) {
        byId.remove(key);
      }
      outboxKeys.clear();
      for (final m in pending) {
        final chatMessage = m.toChatMessage();
        byId[chatMessage.id] = chatMessage;
        outboxKeys.add(chatMessage.id);
      }
      emit();
    }

    Future<void> refreshMessages() async {
      try {
        final json = await api.get('/chats/$chatId/messages', query: {'limit': limit.toString()});
        final rawList = (json['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map));
        for (final raw in rawList) {
          byId[raw['id'] as String] = ChatMessage.fromJson(raw);
          rawById[raw['id'] as String] = raw;
        }
        emit();
        await persistCache();
      } catch (_) {
        // Leave the stream open — the cache already loaded above shows
        // whatever's locally known, and a later socket event or retry can
        // still populate fresher data.
      }
    }

    controller = StreamController<List<ChatMessage>>.broadcast(
      onListen: () async {
        socket.joinChat(chatId);
        sub = socket.newMessages.listen((data) {
          if (data['chatId'] != chatId) return;
          final raw = Map<String, dynamic>.from(data['message'] as Map);
          byId[raw['id'] as String] = ChatMessage.fromJson(raw);
          rawById[raw['id'] as String] = raw;
          emit();
          persistCache();
        });
        sentSub = _sentMessages.stream.where((e) => e.chatId == chatId).listen((e) {
          final raw = e.raw;
          byId[raw['id'] as String] = ChatMessage.fromJson(raw);
          rawById[raw['id'] as String] = raw;
          emit();
          persistCache();
        });
        outboxSub = _outboxChanged.stream.where((id) => id == chatId).listen((_) => refreshOutbox());
        // A reconnect gets a brand-new socket connection server-side, which
        // drops this chat's room membership — a message sent while briefly
        // disconnected (app backgrounded, network blip) never arrives as a
        // live event, even though its push notification still fires
        // (that's server-side and independent of socket room membership).
        // Re-join and re-sync on every reconnect, not just the first
        // subscribe, so the chat always catches up on its own.
        reconnectSub = socket.connected.listen((_) {
          socket.joinChat(chatId);
          refreshMessages();
        });
        // Show whatever's cached locally immediately — including fully
        // offline, before the REST fetch below has any chance to respond.
        await loadCache();
        await refreshOutbox();
        await refreshMessages();
      },
      onCancel: () {
        sub?.cancel();
        outboxSub?.cancel();
        sentSub?.cancel();
        reconnectSub?.cancel();
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
      final saved = await api.post('/chats/${message.chatId}/messages', body: message.toRequestBody());
      // Publish the confirmed message first, so the list already contains it
      // by the time the optimistic placeholder is removed below. Ordering
      // matters: reversing these two leaves a gap where the message is in
      // neither the outbox nor byId, and it visibly disappears.
      if (saved['id'] != null && !_sentMessages.isClosed) {
        _sentMessages.add((chatId: message.chatId, raw: saved));
      }
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
