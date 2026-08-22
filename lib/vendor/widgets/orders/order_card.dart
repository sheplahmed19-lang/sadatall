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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final divider = isDark ? Colors.white12 : Colors.black12;

    final total = (order.displayPrice ?? 0) + (order.deliveryPrice ?? 0);
    final hasTotal = order.deliveryPrice != null && order.deliveryPrice != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: divider),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: order number + status ───────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                color: isDark ? Colors.white10 : Colors.grey[50],
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'طلب #${order.id}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusChip(order.status),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Who ────────────────────────────────────────────────
                    // Rows are only rendered when they carry a value, so an
                    // order without an address no longer shows a bare icon.
                    if (order.user != null && order.user!.name.isNotEmpty)
                      _iconLine(
                        Icons.person_outline,
                        order.user!.name,
                        muted,
                        bold: true,
                      ),
                    if (order.phoneNumber.isNotEmpty &&
                        order.phoneNumber != 'غير محدد')
                      _iconLine(Icons.phone_outlined, order.phoneNumber, muted),
                    if (order.userAddress.trim().isNotEmpty)
                      _iconLine(
                        Icons.location_on_outlined,
                        order.userAddress,
                        muted,
                        maxLines: 2,
                      ),
                    if (order.captain != null &&
                        order.captain!.userName.isNotEmpty)
                      _iconLine(
                        Icons.delivery_dining_outlined,
                        'المندوب: ${order.captain!.userName}',
                        muted,
                        bold: true,
                      ),
                    if (order.routeLabel != null)
                      _iconLine(Icons.alt_route, order.routeLabel!, muted)
                    else if (order.neighborhood != null)
                      _iconLine(
                        Icons.location_city_outlined,
                        order.neighborhood!.name,
                        muted,
                      ),
                    if (order.waitingTime != null)
                      _iconLine(
                        Icons.access_time,
                        'وقت الانتظار: ${order.waitingTime} دقيقة',
                        muted,
                      ),

                    // ── What ───────────────────────────────────────────────
                    if (order.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          order.description,
                          style: const TextStyle(fontSize: 13.5, height: 1.35),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],

                    if (order.additionalNotes != null &&
                        order.additionalNotes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sticky_note_2_outlined,
                              size: 15, color: muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              order.additionalNotes!,
                              style: TextStyle(fontSize: 12.5, color: muted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Money ──────────────────────────────────────────────
                    // Only shown once there is something real to display, so
                    // a pending order is not padded out with "--" rows.
                    if (order.displayPrice != null ||
                        order.deliveryPrice != null) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: divider),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (order.displayPrice != null &&
                              order.displayPrice != 0)
                            _pricePill(
                              order.price != null && order.price != 0
                                  ? 'السعر'
                                  : 'تقديري',
                              order.displayPrice!,
                              Colors.green,
                              isDark,
                            ),
                          if (order.deliveryPrice != null &&
                              order.deliveryPrice != 0) ...[
                            const SizedBox(width: 6),
                            _pricePill(
                              'التوصيل',
                              order.deliveryPrice!,
                              Colors.orange,
                              isDark,
                            ),
                          ],
                          const Spacer(),
                          if (hasTotal)
                            Text(
                              '${total.toStringAsFixed(2)} ج.م',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.lightBlue[200]
                                    : Colors.blue[700],
                              ),
                            ),
                        ],
                      ),
                    ],

                    // ── When ───────────────────────────────────────────────
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 13, color: muted),
                        const SizedBox(width: 4),
                        Text(
                          _formatTZDateTime(order.createdAt),
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                        const Spacer(),
                        Text(
                          'التفاصيل',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                        Icon(
                          Icons.chevron_left,
                          size: 18,
                          color: theme.primaryColor,
                        ),
                      ],
                    ),

                    // ── Items preview ──────────────────────────────────────
                    if (order.orderItems != null &&
                        order.orderItems!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Divider(height: 1, color: divider),
                      const SizedBox(height: 8),
                      Text(
                        'عناصر الطلب (${order.orderItems!.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...order.orderItems!
                          .take(2)
                          .map((item) => _buildOrderItem(item)),
                      if (order.orderItems!.length > 2)
                        Text(
                          'و ${order.orderItems!.length - 2} عناصر أخرى...',
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One labelled detail line. Kept compact so several can stack without the
  /// card becoming a wall of evenly-weighted grey text.
  Widget _iconLine(
    IconData icon,
    String text,
    Color muted, {
    bool bold = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pricePill(String label, double value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: ${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? color.withValues(alpha: 0.95) : color,
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
