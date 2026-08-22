import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../utils/time_utils.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;
  final Function(String) onAction;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        shadowColor: const Color.fromARGB(31, 127, 6, 6),
        color: const Color.fromARGB(
          255,
          127,
          194,
          13,
        ), // Light orange (Amber 100)
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with order ID and status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'طلب #${order.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer info
                if (order.user != null) ...[
                  Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.user!.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],

                // Vendor info
                Row(
                  children: [
                    Icon(Icons.store, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.vendorId == -1
                            ? 'طلب مخصص'
                            : (order.vendor?.vendorName ?? 'متجر غير محدد'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Phone number
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      order.phoneNumber,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.description,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 20,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                if (order.additionalNotes != null &&
                    order.additionalNotes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order.additionalNotes!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[700],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Footer with price, time and actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price and time
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (order.price > 0 || order.deliveryPrice != null) ...[
                          if (order.price > 0 &&
                              (order.deliveryPrice != null &&
                                  order.deliveryPrice! > 0)) ...[
                            // Show total price when both are strictly > 0
                            Text(
                              'الإجمالي: ${order.totalPrice!.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ] else ...[
                            // Show total with placeholders if any is zero or missing
                            Text(
                              'الإجمالي: -- ج.م',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                          const SizedBox(height: 2),
                          // Show breakdown with placeholders
                          Text(
                            'الطلب: ${order.price > 0 ? order.price.toStringAsFixed(2) : '--'} | التوصيل: ${order.deliveryPrice != null && order.deliveryPrice! > 0 ? order.deliveryPrice!.toStringAsFixed(2) : '--'}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                        Text(
                          _formatDateTime(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    // Action buttons
                    _buildActionButtons(),
                  ],
                ),

                // Order items preview
                if (order.orderItems != null &&
                    order.orderItems!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'عناصر الطلب (${order.orderItems!.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...order.orderItems!
                      .take(2)
                      .map((item) => _buildOrderItem(item)),
                  if (order.orderItems!.length > 2) ...[
                    const SizedBox(height: 4),
                    Text(
                      'و ${order.orderItems!.length - 2} عناصر أخرى...',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.blue[100]!; // Light blue for pending
        textColor = Colors.blue[800]!;
        break;
      case OrderStatus.counterOfferAccepted:
        backgroundColor =
            Colors.green[100]!; // Light green for accepted counter offer
        textColor = Colors.green[800]!;
        break;
      case OrderStatus.acceptedByCaptain:
        backgroundColor = Colors.purple[100]!;
        textColor = Colors.purple[800]!;
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        OrderStatus.getStatusDisplayName(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    List<Widget> buttons = [];

    switch (order.status) {
      case OrderStatus.counterOfferAccepted:
      case OrderStatus.acceptedByCaptain:
        // Can view captain location
        if (order.captainLatitude != null && order.captainLongitude != null) {
          buttons = [
            _buildActionButton(
              'موقع الكابتن',
              Icons.location_on,
              Colors.blue,
              () => onAction('view_captain'),
            ),
          ];
        }
        break;
      default:
        // No action buttons for other statuses - user can tap card to view details
        break;
    }

    return Row(children: buttons);
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${item.quantity}x ${item.menu?.name ?? 'عنصر غير معروف'}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${item.price.toStringAsFixed(2)} ج.م',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return TimeUtils.formatRelativeTimeArabic(dateTime);
  }
}
