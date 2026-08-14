import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/clickable_phone_text.dart';
import '../../../../core/utils/app_utils.dart';
import '../../data/models/order_model.dart';
import '../providers/orders_provider.dart';
import '../widgets/order_attachments_widget.dart';
import '../../../chat/captain_order_chat_screen.dart';

class CurrentOrderScreen extends ConsumerStatefulWidget {
  const CurrentOrderScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CurrentOrderScreen> createState() => _CurrentOrderScreenState();
}

class _CurrentOrderScreenState extends ConsumerState<CurrentOrderScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(currentOrdersProvider.notifier).loadCurrentOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentOrdersState = ref.watch(currentOrdersProvider);

    if (currentOrdersState.isLoading && currentOrdersState.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (currentOrdersState.error != null && currentOrdersState.orders.isEmpty) {
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
                currentOrdersState.error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CustomButton(
                text: 'إعادة المحاولة',
                onPressed: () {
                  ref.read(currentOrdersProvider.notifier).loadCurrentOrders();
                },
                type: ButtonType.outlined,
              ),
            ],
          ),
        ),
      );
    }

    if (currentOrdersState.orders.isEmpty) {
      return _buildNoOrderState(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(currentOrdersProvider.notifier).loadCurrentOrders();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: currentOrdersState.orders.length,
        itemBuilder: (context, index) {
          final order = currentOrdersState.orders[index];
          final isProcessing = currentOrdersState.processingOrderId == order.id;
          return Column(
            children: [
              if (index > 0) ...[
                const Divider(height: 32, thickness: 2),
                const SizedBox(height: 8),
              ],
              _buildOrderCard(
                context,
                order,
                isProcessing,
                index + 1,
                currentOrdersState.orders.length,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoOrderState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 80,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'لا يوجد طلبات حالية',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'لا تحمل أي طلبات في الوقت الحالي\nيمكنك البحث عن طلبات متاحة في التبويب الثاني',
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

  Widget _buildOrderCard(
    BuildContext context,
    OrderModel order,
    bool isProcessing,
    int orderNumber,
    int totalOrders,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order header with number indicator if multiple orders
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (totalOrders > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$orderNumber',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          'رقم الطلب: #${order.id}',
                          style: Theme.of(context).textTheme.titleLarge,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusText(order.status),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOrderInfo('المطعم/المتجر:', order.vendorName),
            if (order.vendor != null)
              _buildPhoneInfo(
                'رقم المطعم/المتجر:',
                order.vendor!.contactNumber,
              ),
            if (order.description.isNotEmpty)
              _buildOrderInfoWithClickablePhones(
                'وصف الطلب:',
                order.description,
              ),
            if (order.neighborhood != null)
              _buildOrderInfo('الحي:', order.neighborhood!.name),
            if (order.routeLabel != null)
              _buildOrderInfo('المسار:', order.routeLabel!),
            _buildOrderInfo('عنوان التسليم:', order.userAddress),
            _buildPhoneInfo('رقم الهاتف:', order.phoneNumber),
            if (order.price != null)
              _buildOrderInfo('سعر الطلب:', AppUtils.formatPrice(order.price!)),
            if (order.deliveryPrice != null)
              _buildOrderInfo(
                'سعر التوصيل:',
                AppUtils.formatPrice(order.deliveryPrice!),
              ),
            if (order.waitingTime != null)
              _buildOrderInfo('الوقت التقديري:', '${order.waitingTime} دقيقة'),
            _buildOrderInfo(
              'وقت الطلب:',
              AppUtils.formatDateTime(order.createdAt.toLocal()),
            ),
            if (order.additionalNotes != null &&
                order.additionalNotes!.isNotEmpty)
              _buildOrderInfoWithClickablePhones(
                'ملاحظات:',
                order.additionalNotes!,
              ),
            if (order.attachments != null && order.attachments!.isNotEmpty)
              OrderAttachmentsWidget(attachments: order.attachments!),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'تم التسليم',
                    onPressed: isProcessing
                        ? null
                        : () {
                            _markAsDelivered(order.id);
                          },
                    isLoading: isProcessing,
                    backgroundColor: AppColors.success,
                    icon: Icons.check_circle,
                    height: 40,
                  ),
                ),
                const SizedBox(width: 8),
                // Calling the customer is the other thing a captain needs at
                // this point, so it sits next to the delivery action rather
                // than only being reachable from the phone row above.
                CustomButton(
                  text: 'اتصال',
                  onPressed: isProcessing
                      ? null
                      : () => _callPhone(order.phoneNumber),
                  backgroundColor: AppColors.primary,
                  icon: Icons.phone,
                  height: 40,
                  width: 120,
                ),
              ],
            ),
            if (order.user != null) ...[
              const SizedBox(height: 8),
              CustomButton(
                text: 'محادثة مع العميل',
                onPressed: isProcessing
                    ? null
                    : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CaptainOrderChatScreen(
                            orderId: order.id,
                            otherId: order.user!.id,
                            otherName: order.user!.userName,
                            isVendor: false,
                            orderStatus: order.status.value,
                          ),
                        ));
                      },
                type: ButtonType.outlined,
                icon: Icons.chat_bubble_outline,
                height: 40,
              ),
            ],
            if (order.vendor != null && order.vendorId != '-1') ...[
              const SizedBox(height: 8),
              CustomButton(
                text: 'محادثة مع المتجر',
                onPressed: isProcessing
                    ? null
                    : () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CaptainOrderChatScreen(
                            orderId: order.id,
                            otherId: order.vendor!.id,
                            otherName: order.vendor!.vendorName,
                            isVendor: true,
                            orderStatus: order.status.value,
                          ),
                        ));
                      },
                type: ButtonType.outlined,
                icon: Icons.storefront_outlined,
                height: 40,
              ),
            ],
            const SizedBox(height: 8),
            CustomButton(
              text: 'إشعار العميل بالوصول',
              onPressed: isProcessing
                  ? null
                  : () {
                      _notifyUserArrived(order.id);
                    },
              type: ButtonType.outlined,
              icon: Icons.notifications_active,
              height: 40,
            ),
            if (order.userLatitude != null && order.userLongitude != null) ...[
              const SizedBox(height: 8),
              CustomButton(
                text: 'موقع العميل',
                onPressed: () {
                  _openInMaps(order.userLatitude!, order.userLongitude!);
                },
                type: ButtonType.outlined,
                icon: Icons.map,
                height: 40,
              ),
            ],
            if (order.vendor?.latitude != null &&
                order.vendor?.longitude != null) ...[
              const SizedBox(height: 8),
              CustomButton(
                text: 'موقع المطعم',
                onPressed: () {
                  _openInMaps(
                    order.vendor!.latitude!,
                    order.vendor!.longitude!,
                  );
                },
                type: ButtonType.outlined,
                icon: Icons.store,
                height: 40,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneInfo(String label, String phoneNumber) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: ClickablePhoneField(phoneNumber: phoneNumber)),
        ],
      ),
    );
  }

  Widget _buildOrderInfoWithClickablePhones(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClickablePhoneText(
              text: value,
              style: TextStyle(color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'في انتظار الموافقة';
      case OrderStatus.counterOfferSent:
        return 'عرض مضاد مُرسل';
      case OrderStatus.counterOfferAccepted:
        return 'عرض مضاد مقبول';
      case OrderStatus.acceptedByCaptain:
        return 'مقبول من الكابتن';
      case OrderStatus.delivered:
        return 'تم التوصيل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.counterOfferSent:
        return AppColors.info;
      case OrderStatus.counterOfferAccepted:
        return AppColors.accepted;
      case OrderStatus.acceptedByCaptain:
        return AppColors.accepted;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  void _callPhone(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الهاتف')),
        );
      }
    }
  }

  void _openInMaps(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط')),
        );
      }
    }
  }

  void _notifyUserArrived(String orderId) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await ref
          .read(currentOrdersProvider.notifier)
          .notifyArrived(orderId);

      // Hide loading indicator - always close it
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إشعار العميل بوصولك')),
          );
        }
      } else {
        final error = ref.read(currentOrdersProvider).error;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? 'فشل في إرسال الإشعار')),
          );
        }
      }
    } catch (e) {
      // Ensure loading dialog is closed even if there's an unexpected error
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حدث خطأ غير متوقع')));
      }
    }
  }

  void _markAsDelivered(String orderId) async {
    if (!mounted) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('تأكيد التسليم'),
          content: const Text('هل تم تسليم الطلب بنجاح للعميل؟'),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child: const Text('تأكيد'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    // User pressed cancel or dismissed the dialog
    if (confirmed != true) return;
    if (!mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final success = await ref
          .read(currentOrdersProvider.notifier)
          .markDelivered(orderId);

      if (!mounted) return;

      // Close loading dialog safely using rootNavigator
      Navigator.of(context, rootNavigator: true).pop();

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم تسليم الطلب بنجاح')));
        }
      } else {
        final error = ref.read(currentOrdersProvider).error;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error ?? 'فشل في تسليم الطلب')),
          );
        }
      }
    } catch (e) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حدث خطأ غير متوقع')));
      }
    }
  }
}
