import 'package:flutter/material.dart';
import '../../models/chat_message.dart';

class OrderRefCard extends StatelessWidget {
  final OrderRef orderRef;
  final Color accentColor;
  final VoidCallback? onTap;

  const OrderRefCard({
    super.key,
    required this.orderRef,
    required this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'طلب #${orderRef.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    orderRef.statusSnapshot,
                    style: TextStyle(
                      fontSize: 12,
                      // grey[700] is near-black: it disappeared against the
                      // dark-mode surface behind this card.
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, size: 18),
          ],
        ),
      ),
    );
  }
}
