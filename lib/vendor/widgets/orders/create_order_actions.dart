import 'package:flutter/material.dart';

/// The two ways a vendor can start an order, shown above the orders list.
///
/// - Customer order: delivered to a customer, so it collects their phone,
///   address and neighbourhood (the long-standing flow).
/// - Shop order: something the shop itself needs, delivered to the shop, so
///   no customer details are asked for at all.
///
/// Navigation is delegated to the host screen rather than done here, so both
/// cards go through its vendor-locked check.
class CreateOrderActions extends StatelessWidget {
  final void Function({bool isShopOrder}) onCreate;

  const CreateOrderActions({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _ActionCard(
              title: 'طلب توصيل جديد',
              subtitle: 'إرسال طلب للعميل',
              icon: Icons.delivery_dining,
              color: const Color(0xFF00BFA5),
              onTap: () => onCreate(isShopOrder: false),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionCard(
              title: 'طلب  للمتجر',
              subtitle: 'لطلب احتياجات المتجر',
              icon: Icons.shopping_basket,
              color: const Color(0xFF3F51B5),
              onTap: () => onCreate(isShopOrder: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
