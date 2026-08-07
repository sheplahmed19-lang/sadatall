import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import '../data/chat_attachment_service.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/chat_participant.dart';
import '../models/chat_thread.dart';
import '../presence/presence_service.dart';
import 'widgets/attachment_picker_sheet.dart';
import 'widgets/composer_bar.dart';
import 'widgets/message_bubble.dart';
import 'widgets/presence_dot.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/voice_recorder_sheet.dart';

typedef LatLng = ({double lat, double lng});

/// Generic chat screen reused by every mode/chat-type. A mode-specific
/// wrapper (e.g. lib/user/screens/chat/support_chat_screen.dart) supplies
/// [repository] (shared per mode, so the socket connects once per app
/// session), [openThread] (lazy get-or-create), [self], and display bits.
class ChatScreen extends StatefulWidget {
  final ChatRepository repository;
  final Future<ChatThread> Function() openThread;
  final ChatParticipant self;
  final String otherParticipantId;
  final String title;
  final Color accentColor;
  final ChatAttachmentService? attachmentService;
  final Future<LatLng?> Function()? getCurrentLocation;
  final void Function(OrderRef ref)? onOrderRefTap;
  final bool showPresence;

  const ChatScreen({
    super.key,
    required this.repository,
    required this.openThread,
    required this.self,
    required this.otherParticipantId,
    required this.title,
    required this.accentColor,
    this.attachmentService,
    this.getCurrentLocation,
    this.onOrderRefTap,
    this.showPresence = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatRepository _repo = widget.repository;
  late final PresenceService _presence = PresenceService(widget.repository.socket);
  final ScrollController _scrollController = ScrollController();
  ChatThread? _thread;
  String? _error;
  bool _markedReadForCurrentUnread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final thread = await widget.openThread();
      if (mounted) setState(() => _thread = thread);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر فتح المحادثة');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isReadOnly => _thread?.status == ChatStatus.readOnly || _thread?.status == ChatStatus.closed;

  Future<void> _sendText(String text) async {
    final chatId = _thread?.id;
    if (chatId == null) return;
    // Queues locally and appears immediately; never throws — a failed
    // network attempt just leaves the message flagged in the list instead
    // of surfacing an error dialog, and retries automatically on reconnect.
    await _repo.sendTextMessage(chatId: chatId, sender: widget.self, text: text);
  }

  Future<void> _handleAttach() async {
    final chatId = _thread?.id;
    if (chatId == null) return;
    final choice = await showChatAttachmentSheet(context, accentColor: widget.accentColor);
    if (choice == null || !mounted) return;

    switch (choice) {
      case ChatAttachmentChoice.camera:
      case ChatAttachmentChoice.gallery:
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: choice == ChatAttachmentChoice.camera ? ImageSource.camera : ImageSource.gallery,
          imageQuality: 70,
        );
        if (xfile != null) await _uploadAndSend(File(xfile.path), MessageType.image, chatId);
        break;
      case ChatAttachmentChoice.voice:
        if (!mounted) return;
        final file = await showVoiceRecorderSheet(context, accentColor: widget.accentColor);
        if (file != null) await _uploadAndSend(file, MessageType.voice, chatId);
        break;
      case ChatAttachmentChoice.location:
        try {
          final loc = await widget.getCurrentLocation?.call();
          if (loc != null) {
            await _repo.sendLocationMessage(chatId: chatId, sender: widget.self, lat: loc.lat, lng: loc.lng);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحديد الموقع')));
          }
        } catch (e) {
          _showError('تعذر إرسال الموقع', e);
        }
        break;
    }
  }

  Future<void> _uploadAndSend(File file, MessageType type, String chatId) async {
    if (widget.attachmentService == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رفع المرفقات غير متاح')));
      return;
    }
    try {
      final result = await widget.attachmentService!.upload(file: file, chatId: chatId);
      if (result == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل رفع المرفق')));
        return;
      }
      await _repo.sendAttachmentMessage(
        chatId: chatId,
        sender: widget.self,
        type: type,
        attachmentKey: result.key,
        attachmentUrl: result.url,
      );
    } catch (e) {
      _showError('فشل رفع المرفق', e);
    }
  }

  void _showError(String prefix, Object error) {
    final message = '$prefix: $error';
    if (kDebugMode) debugPrint(message);
    if (!mounted) return;
    // A dialog instead of a SnackBar: SnackBars auto-dismiss and clip long
    // text, which made earlier error messages here unreadable/uncopyable
    // (users could only report the first few words before it vanished).
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حدث خطأ'),
        content: SelectableText(message),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('تم النسخ')));
            },
            child: const Text('نسخ'),
          ),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('حسناً')),
        ],
      ),
    );
  }

  void _markReadIfNeeded(List<ChatMessage> messages) {
    final chatId = _thread?.id;
    if (chatId == null) return;
    final hasUnread = messages.any((m) => m.senderId != widget.self.participantId && !m.readBy.contains(widget.self.participantId));
    if (!hasUnread) {
      _markedReadForCurrentUnread = false;
      return;
    }
    if (_markedReadForCurrentUnread) return;
    _markedReadForCurrentUnread = true;
    _repo.markThreadRead(chatId, widget.self.participantId);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: Center(child: Text(_error!)));
    }
    if (_thread == null) {
      return Scaffold(appBar: AppBar(title: Text(widget.title)), body: const Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.accentColor,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Expanded(child: Text(widget.title)),
            if (widget.showPresence) ...[
              PresenceDot(presence: _presence, participantId: widget.otherParticipantId),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isReadOnly)
            Container(
              width: double.infinity,
              color: Colors.amber[100],
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text('محادثة منتهية — للعرض فقط', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ),
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _repo.streamMessages(_thread!.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;
                WidgetsBinding.instance.addPostFrameCallback((_) => _markReadIfNeeded(messages));
                if (messages.isEmpty) {
                  return const Center(child: Text('ابدأ المحادثة الآن', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMine = m.senderId == widget.self.participantId;
                    final isUnconfirmed = m.deliveryStatus != MessageDeliveryStatus.sent;
                    return MessageBubble(
                      message: m,
                      isMine: isMine,
                      isRead: m.readBy.contains(widget.otherParticipantId),
                      accentColor: widget.accentColor,
                      onOrderRefTap: widget.onOrderRefTap,
                      onImageTap: m.attachmentUrl == null ? null : () => _openImage(context, m.attachmentUrl!),
                      // A message still in the outbox was never persisted
                      // server-side, so there's nothing to soft-delete there —
                      // "delete" on a failed one just drops it locally instead.
                      onDelete: !isMine
                          ? null
                          : isUnconfirmed
                              ? (m.deliveryStatus == MessageDeliveryStatus.failed
                                  ? () => _repo.discardFailed(_thread!.id, m.clientMessageId!)
                                  : null)
                              : () => _repo.softDeleteMessage(_thread!.id, m.id),
                      onRetry: m.deliveryStatus == MessageDeliveryStatus.failed
                          ? () => _repo.retryFailed(_thread!.id, m.clientMessageId!)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
          TypingIndicator(presence: _presence, otherParticipantId: widget.otherParticipantId, chatId: _thread!.id),
          ComposerBar(
            accentColor: widget.accentColor,
            enabled: !_isReadOnly,
            onSend: _sendText,
            onChanged: (_) => _presence.setTyping(_thread!.id),
            onAttachTap: _handleAttach,
          ),
        ],
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
        body: Center(child: InteractiveViewer(child: Image.network(url))),
      ),
    ));
  }
}
