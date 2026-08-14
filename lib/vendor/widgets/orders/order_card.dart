import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../models/order.dart';
// import 'package:intl/intl.dart';
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
        elevation: 2,
        shadowColor: Colors.black12,
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
                const SizedBox(height: 6),

                // Address
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.userAddress,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.description,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
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

                // Footer with prices and time (no action buttons - user must go to details)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price, delivery price, and total
                    if (order.displayPrice != null ||
                        order.deliveryPrice != null) ...[
                      _buildPriceText(
                        order.price != null && order.price != 0
                            ? 'السعر: '
                            : 'السعر المطلوب (تقديري): ',
                        order.displayPrice,
                        Colors.green,
                      ),
                      const SizedBox(height: 2),
                      _buildPriceText(
                        'مصاريف التوصيل: ',
                        order.deliveryPrice,
                        Colors.orange,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'الإجمالي: ${order.displayPrice == null || order.deliveryPrice == null || order.deliveryPrice == 0 ? '--' : '${(order.displayPrice! + order.deliveryPrice!).toStringAsFixed(2)} ج.م'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (order.waitingTime != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'وقت الانتظار: ${order.waitingTime} دقيقة',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    if (order.routeLabel != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.alt_route,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              order.routeLabel!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ] else if (order.neighborhood != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.location_city,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'المنطقة: ${order.neighborhood!.name}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      _formatTZDateTime(order.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
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
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case OrderStatus.counterOfferSent:
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      // case OrderStatus.accepted:
      //   backgroundColor = Colors.green[100]!;
      //   textColor = Colors.green[800]!;
      //   break;
      // case OrderStatus.preparing:
      //   backgroundColor = Colors.purple[100]!;
      //   textColor = Colors.purple[800]!;
      //   break;
      // case OrderStatus.ready:
      //   backgroundColor = Colors.teal[100]!;
      //   textColor = Colors.teal[800]!;
      //   break;
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

  Widget _buildPriceText(String label, double? price, Color color) {
    bool isValid = price != null && price != 0;
    return Text(
      '$label${isValid ? '${price!.toStringAsFixed(2)} ج.م' : '--'}',
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
    );
  }

  String _formatTZDateTime(tz.TZDateTime dateTime) {
    final now = TimeUtils.currentTimeInCairo;
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return TimeUtils.formatCairoTZDateTime(dateTime, format: 'dd/MM/yyyy');
    } else if (difference.inHours > 0) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
