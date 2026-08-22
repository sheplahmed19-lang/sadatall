import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/order_model.dart';
import '../providers/orders_provider.dart';
import '../widgets/order_attachments_widget.dart';
import '../../../../core/widgets/clickable_phone_text.dart';
import '../../../../main_navigation.dart';

class AvailableOrdersScreen extends ConsumerStatefulWidget {
  const AvailableOrdersScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AvailableOrdersScreen> createState() =>
      _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends ConsumerState<AvailableOrdersScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentState = ref.read(availableOrdersProvider);
      if (currentState.orders.isEmpty && !currentState.isLoading) {
        ref.read(availableOrdersProvider.notifier).loadOrders();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final state = ref.read(availableOrdersProvider);
      if (state.isAccepting) return;
      ref
          .read(availableOrdersProvider.notifier)
          .loadOrders(refresh: true, silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final state = ref.read(availableOrdersProvider);
      if (!state.isLoading && state.hasMore) {
        ref.read(availableOrdersProvider.notifier).loadOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(availableOrdersProvider);

    if (ordersState.orders.isEmpty && !ordersState.isLoading) {
      return _buildEmptyState(context);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(availableOrdersProvider.notifier)
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
          return _buildOrderCard(
            context,
            ordersState.orders[index],
            ordersState,
          );
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
              Icons.shopping_cart_outlined,
              size: 80,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'لا توجد طلبات متاحة',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'لا توجد طلبات متاحة في الوقت الحالي\nسيتم إشعارك عند توفر طلبات جديدة',
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
    AvailableOrdersState ordersState,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        // Roomier than the original 10px: the text on this card was raised to
        // 14-17px for outdoor legibility, and tight padding around larger type
        // reads as cramped and hurts scanning in bright light.
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'رقم الطلب: #${order.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (order.vendorId == '-1') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.warning.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'طلب خاص',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.warning,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (order.deliveryPrice != null)
                  Text(
                    AppUtils.formatPrice(order.deliveryPrice!),
                    style: const TextStyle(
                      fontSize: 17,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.store, size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.vendorName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  AppUtils.timeAgo(order.createdAt),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Grouped pickup -> delivery -> order, in the sequence the captain
            // actually works through the job. Kept identical to
            // CurrentOrderScreen so the same order reads the same way before
            // and after it is accepted.
            if (order.vendorId != '-1') ...[
              _buildSectionHeader(Icons.storefront, 'الاستلام'),
              if (order.vendor != null)
                _buildPhoneRow('رقم المتجر:', order.vendor!.contactNumber),
              if (order.routeLabel != null)
                _buildDetailRow('المسار:', order.routeLabel!),
              const SizedBox(height: 8),
            ],

            _buildSectionHeader(Icons.person_pin_circle, 'التسليم'),
            // The backend already sends the customer on this endpoint
            // (getAvailableOrders includes user.userName), but the card only
            // ever showed order.phoneNumber, so the captain saw a bare number
            // with no idea who it belonged to — while admin showed the name
            // for the same order.
            _buildDetailRow('اسم العميل:', order.displayCustomerName),
            _buildPhoneRow('رقم الهاتف:', order.phoneNumber),
            const SizedBox(height: 8),

            _buildSectionHeader(Icons.receipt_long, 'تفاصيل الطلب'),
            if (order.description.isNotEmpty) _buildDescriptionBlock(order),
            if (order.price != null)
              _buildDetailRow('سعر الطلب:', AppUtils.formatPrice(order.price!)),
            if (order.waitingTime != null)
              _buildDetailRow('الوقت التقديري:', '${order.waitingTime} دقيقة'),
            if (order.additionalNotes != null &&
                order.additionalNotes!.isNotEmpty)
              _buildDetailRowWithClickablePhones(
                'ملاحظات:',
                order.additionalNotes!,
              ),
            if (order.attachments != null && order.attachments!.isNotEmpty) ...[
              const SizedBox(height: 4),
              OrderAttachmentsWidget(attachments: order.attachments!),
            ],
            if (order.userLatitude != null && order.userLongitude != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () =>
                    _openInMaps(order.userLatitude!, order.userLongitude!),
                child: Row(
                  children: [
                    const Icon(
                      Icons.map_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'عرض الموقع على الخريطة',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            CustomButton(
              text: 'قبول الطلب',
              onPressed:
                  ordersState.isAccepting &&
                      ordersState.acceptingOrderId == order.id
                  ? null
                  : () {
                      _acceptOrder(context, order);
                    },
              isLoading:
                  ordersState.isAccepting &&
                  ordersState.acceptingOrderId == order.id,
              height: 34,
            ),
          ],
        ),
      ),
    );
  }

  /// Small heading that separates the pickup / delivery / order blocks so the
  /// captain can find one piece of information without reading the whole card.
  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Divider(
              height: 1,
              color: AppColors.primary.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneRow(String label, String phoneNumber) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClickablePhoneField(
              phoneNumber: phoneNumber,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          // Heavier than its label: in glare the eye lands on the strongest
          // mark first, and the value is what the captain is looking for.
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  /// The order description, given its own full-width block instead of a
  /// `label: value` row.
  ///
  /// This is the one field the captain has to actually read — it says what to
  /// pick up — and as a cramped row it looked no more important than the
  /// waiting time. Full width, larger and heavier type, and a tinted panel
  /// with a leading accent bar give it a shape the eye finds immediately in
  /// direct sunlight, without needing to parse any label first.
  Widget _buildDescriptionBlock(OrderModel order) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        // A tint pale enough to keep text at ~15:1 is necessarily within about
        // 1.1:1 of the white card, so the fill alone cannot carry the emphasis
        // outdoors. The saturated bar and full-strength border do that work —
        // colour at full chroma is what survives glare.
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryDark, width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 8,
              decoration: const BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.horizontal(
                  right: Radius.circular(6),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وصف الطلب',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClickablePhoneText(
                      text: order.description,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRowWithClickablePhones(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClickablePhoneText(
              text: value,
              style: TextStyle(fontSize: 14, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  void _acceptOrder(BuildContext context, OrderModel order) async {
    // Special orders (vendorId == -1) normally need the captain to name a
    // delivery price — but an admin can create one with the price already
    // set, and then there is nothing for the captain to decide. Only ask
    // when the order has no price yet.
    if (order.vendorId == '-1' && order.deliveryPrice == null) {
      _showDeliveryPriceDialog(context, order);
      return;
    }

    // For normal orders, show confirmation dialog
    final parentContext = context; // save the screen context

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('قبول الطلب'),
          content: Text('هل تريد قبول طلب #${order.id}؟.'),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('قبول'),
              onPressed: () async {
                final notifier = ref.read(availableOrdersProvider.notifier);
                Navigator.of(dialogContext).pop();

                final success = await notifier.acceptOrder(order.id);

                if (!mounted) return;

                if (success) {
                  ref.read(switchToCurrentOrderTab)?.call();
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('تم قبول الطلب بنجاح'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  final error = ref.read(availableOrdersProvider).error;
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(child: Text(error ?? 'فشل في قبول الطلب')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeliveryPriceDialog(BuildContext context, OrderModel order) {
    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController();
    final parentContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('تحديد سعر التوصيل'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'طلب خاص #${order.id}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يجب تحديد سعر التوصيل للطلبات الخاصة',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'سعر التوصيل',
                  hint: 'أدخل سعر التوصيل',
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefixIcon: const Icon(Icons.attach_money),
                  validator: Validators.deliveryPrice,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            Consumer(
              builder: (context, dialogRef, child) {
                final state = dialogRef.watch(availableOrdersProvider);
                final isLoading =
                    state.isAccepting && state.acceptingOrderId == order.id;
                return TextButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          final deliveryPrice = double.tryParse(
                            priceController.text,
                          );
                          if (deliveryPrice == null || deliveryPrice <= 0) {
                            return;
                          }

                          final notifier = dialogRef.read(
                            availableOrdersProvider.notifier,
                          );
                          Navigator.of(dialogContext).pop();

                          final success = await notifier.acceptOrder(
                            order.id,
                            deliveryPrice: deliveryPrice,
                          );

                          if (!mounted) return;

                          if (success) {
                            ref.read(switchToCurrentOrderTab)?.call();
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text('تم قبول الطلب بنجاح'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 4),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            final error = ref
                                .read(availableOrdersProvider)
                                .error;
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      Icons.error,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(error ?? 'فشل في قبول الطلب'),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 4),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('قبول'),
                );
              },
            ),
          ],
        );
      },
    );
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
}
