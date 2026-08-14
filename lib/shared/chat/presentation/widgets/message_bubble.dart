import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_message.dart';
import 'order_ref_card.dart';
import 'voice_message_bubble.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool isRead;
  final Color accentColor;
  final void Function(OrderRef ref)? onOrderRefTap;
  final VoidCallback? onDelete;
  final VoidCallback? onImageTap;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.isRead,
    required this.accentColor,
    this.onOrderRefTap,
    this.onDelete,
    this.onImageTap,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[800]),
          ),
        ),
      );
    }

    // The received bubble follows the theme so its text stays legible in dark
    // mode; the sent bubble keeps the accent colour, which is dark enough for
    // white text in both themes.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMine
        ? accentColor
        : (isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]!);
    final textColor = isMine
        ? Colors.white
        : (isDark ? Colors.white : Colors.black87);

    return Align(
      // Physical (not directional) alignment: the app is forced RTL, so
      // AlignmentDirectional.centerEnd would put the sender on the left.
      // Sent messages always sit on the right, received ones on the left.
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(context),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(10),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildContent(context, textColor),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.deliveryStatus ==
                      MessageDeliveryStatus.failed) ...[
                    Text(
                      'بحاجة إلى إنترنت',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.red[100] ?? Colors.red,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ] else
                    Text(
                      _formatTime(message.sentAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  if (isMine) ...[
                    const SizedBox(width: 4),
                    _buildStatusIcon(textColor),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Color textColor) {
    switch (message.deliveryStatus) {
      case MessageDeliveryStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: textColor.withOpacity(0.7),
          ),
        );
      case MessageDeliveryStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(
            Icons.error_outline,
            size: 15,
            color: Colors.redAccent,
          ),
        );
      case MessageDeliveryStatus.sent:
        return Icon(
          isRead ? Icons.done_all : Icons.done,
          size: 14,
          color: isRead ? Colors.lightBlueAccent : textColor.withOpacity(0.7),
        );
    }
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    if (message.isDeleted) {
      return Text(
        'تم حذف هذه الرسالة',
        style: TextStyle(
          color: textColor.withOpacity(0.6),
          fontStyle: FontStyle.italic,
        ),
      );
    }
    switch (message.type) {
      case MessageType.text:
        return Text(message.text ?? '', style: TextStyle(color: textColor));
      case MessageType.image:
        return GestureDetector(
          onTap: onImageTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: message.attachmentUrl == null
                ? const SizedBox(
                    width: 160,
                    height: 160,
                    child: Icon(Icons.image),
                  )
                : Image.network(
                    message.attachmentUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            width: 200,
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (c, e, s) => const SizedBox(
                      width: 200,
                      height: 200,
                      child: Icon(Icons.broken_image),
                    ),
                  ),
          ),
        );
      case MessageType.voice:
        return message.attachmentUrl == null
            ? const Text('رسالة صوتية')
            : VoiceMessageBubble(url: message.attachmentUrl!, color: textColor);
      case MessageType.location:
        return _LocationPreview(message: message, textColor: textColor);
      case MessageType.orderRef:
        return message.orderRef == null
            ? const SizedBox.shrink()
            : OrderRefCard(
                orderRef: message.orderRef!,
                accentColor: accentColor,
                onTap: onOrderRefTap == null
                    ? null
                    : () => onOrderRefTap!(message.orderRef!),
              );
      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: textColor),
            const SizedBox(width: 6),
            Text(message.text ?? 'ملف', style: TextStyle(color: textColor)),
          ],
        );
      case MessageType.video:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: textColor),
            const SizedBox(width: 6),
            Text('فيديو', style: TextStyle(color: textColor)),
          ],
        );
      case MessageType.system:
        return const SizedBox.shrink();
    }
  }

  void _showActions(BuildContext context) {
    if (message.isDeleted || message.type == MessageType.system) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (message.type == MessageType.text &&
                (message.text?.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('نسخ'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text ?? ''));
                  Navigator.pop(ctx);
                },
              ),
            if (isMine && onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('حذف', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:$m $period';
  }
}

class _LocationPreview extends StatelessWidget {
  final ChatMessage message;
  final Color textColor;
  const _LocationPreview({required this.message, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final loc = message.location;
    return InkWell(
      onTap: loc == null
          ? null
          : () async {
              final uri = Uri.parse(
                'https://www.google.com/maps/search/?api=1&query=${loc.lat},${loc.lng}',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: textColor),
          const SizedBox(width: 6),
          Text(
            'فتح الموقع في الخرائط',
            style: TextStyle(
              color: textColor,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}
