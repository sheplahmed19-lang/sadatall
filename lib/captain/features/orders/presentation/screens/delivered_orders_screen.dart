import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../data/models/order_model.dart';
import '../providers/orders_provider.dart';
import 'delivered_order_details_screen.dart';

class DeliveredOrdersScreen extends ConsumerStatefulWidget {
  const DeliveredOrdersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DeliveredOrdersScreen> createState() =>
      _DeliveredOrdersScreenState();
}

class _DeliveredOrdersScreenState extends ConsumerState<DeliveredOrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load orders only if there are no existing orders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = ref.read(deliveredOrdersProvider);
      if (currentState.orders.isEmpty && !currentState.isLoading) {
        ref.read(deliveredOrdersProvider.notifier).loadOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final state = ref.read(deliveredOrdersProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(deliveredOrdersProvider.notifier).loadOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(deliveredOrdersProvider);

    if (ordersState.orders.isEmpty && !ordersState.isLoading) {
      return _buildEmptyState(context);
    }

    if (ordersState.error != null && ordersState.orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'حدث خطأ',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                ordersState.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'إعادة المحاولة',
                onPressed: () {
                  ref
                      .read(deliveredOrdersProvider.notifier)
                      .loadOrders(refresh: true);
                },
                type: ButtonType.outlined,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(deliveredOrdersProvider.notifier)
            .loadOrders(refresh: true);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: ordersState.orders.length + (ordersState.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == ordersState.orders.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _buildOrderCard(context, ordersState.orders[index]);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد طلبات مكتملة',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'لم تكمل أي طلبات حتى الآن\nستظهر طلباتك المكتملة هنا',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeliveredOrderDetailsScreen(order: order),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رقم الطلب: #${order.id}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.delivered,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'مكتمل',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.store,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.vendorName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${order.neighborhood?.name ?? ''} - ${order.userAddress}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.delivered,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'تم التسليم: ${order.deliveredAt != null ? AppUtils.formatDateTime(order.deliveredAt!.toLocal()) : 'غير محدد'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  if (order.deliveryPrice != null)
                    Text(
                      AppUtils.formatPrice(order.deliveryPrice!),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.delivered,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
              if (order.additionalNotes != null &&
                  order.additionalNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.note,
                      size: 16,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'ملاحظات: ${order.additionalNotes!}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
