import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../../../core/widgets/clickable_phone_text.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/order_model.dart';
import '../providers/orders_provider.dart';
import '../widgets/order_attachments_widget.dart';

class SpecialOrderDetailsScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const SpecialOrderDetailsScreen({Key? key, required this.order}) : super(key: key);

  @override
  ConsumerState<SpecialOrderDetailsScreen> createState() => _SpecialOrderDetailsScreenState();
}

class _SpecialOrderDetailsScreenState extends ConsumerState<SpecialOrderDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(availableOrdersProvider);
    final isAccepting = ordersState.isAccepting && ordersState.acceptingOrderId == widget.order.id;

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب خاص #${widget.order.id}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Special order indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: AppColors.warning),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا طلب خاص - يجب تحديد سعر التوصيل عند القبول',
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Order details card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تفاصيل الطلب',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('رقم الطلب:', '#${widget.order.id}'),
                    _buildDetailRowWithClickablePhones('وصف الطلب:', widget.order.description),
                    _buildDetailRow(
                      'الحي:',
                      widget.order.neighborhood?.name ?? 'غير محدد',
                    ),
                    _buildDetailRow('اسم العميل:', _displayCustomerName()),
                    _buildDetailRow('عنوان العميل:', widget.order.userAddress),
                    _buildPhoneDetailRow('رقم الهاتف:', widget.order.phoneNumber),
                    if (widget.order.price != null)
                      _buildDetailRow(
                        'سعر الطلب:',
                        AppUtils.formatPrice(widget.order.price!),
                      ),
                    _buildDetailRow(
                      'وقت الطلب:',
                      AppUtils.formatDateTime(widget.order.createdAt.toLocal()),
                    ),
                    if (widget.order.additionalNotes != null &&
                        widget.order.additionalNotes!.isNotEmpty)
                      _buildDetailRowWithClickablePhones('ملاحظات:', widget.order.additionalNotes!),
                    // Display attachments for special orders (vendorId == '-1')
                    if (widget.order.vendorId == '-1' &&
                        widget.order.attachments != null &&
                        widget.order.attachments!.isNotEmpty)
                      OrderAttachmentsWidget(attachments: widget.order.attachments!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            if (widget.order.userLatitude != null && widget.order.userLongitude != null)
              CustomButton(
                text: 'عرض موقع العميل على الخريطة',
                onPressed: () {
                  _openInMaps(widget.order.userLatitude!, widget.order.userLongitude!);
                },
                type: ButtonType.outlined,
                icon: Icons.map,
              ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'قبول الطلب',
              onPressed: isAccepting ? null : () {
                // An admin can create a special order with the delivery price
                // already set; asking the captain to name one would let them
                // overwrite it. Only prompt when there is no price yet.
                if (widget.order.deliveryPrice == null) {
                  _showDeliveryPriceDialog(context, widget.order);
                } else {
                  _confirmAcceptWithExistingPrice(context, widget.order);
                }
              },
              isLoading: isAccepting,
              icon: Icons.check_circle,
            ),
          ],
        ),
      ),
    );
  }

  String _displayCustomerName() {
    // For send-package orders, the sender's name (which may differ from the
    // account owner) is embedded in additionalNotes as "الاسم: <name>".
    // Prefer that when present; fall back to the account's registered name.
    final notes = widget.order.additionalNotes;
    if (notes != null) {
      final match = RegExp(r'الاسم:\s*(.+)').firstMatch(notes);
      final senderName = match?.group(1)?.trim();
      if (senderName != null && senderName.isNotEmpty) {
        return senderName;
      }
    }
    return widget.order.user?.userName ?? 'غير محدد';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneDetailRow(String label, String phoneNumber) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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
            child: ClickablePhoneField(
              phoneNumber: phoneNumber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithClickablePhones(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
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

  /// Confirmation for a special order whose delivery price the admin already
  /// set: the price is shown, not asked for.
  void _confirmAcceptWithExistingPrice(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد قبول الطلب'),
        content: Column(
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
            const SizedBox(height: 12),
            Text(
              'سعر التوصيل: ${order.deliveryPrice} جنيه',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تم تحديد سعر التوصيل من قبل الإدارة.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          TextButton(
            child: const Text('قبول'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // No price sent — the backend keeps the one already on the order.
              _acceptOrder(order, null);
            },
          ),
        ],
      ),
    );
  }

  void _showDeliveryPriceDialog(BuildContext context, OrderModel order) {
    final formKey = GlobalKey<FormState>();
    final priceController = TextEditingController();

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
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'سعر التوصيل',
                  hint: 'أدخل سعر التوصيل',
                  controller: priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
              builder: (context, ref, child) {
                final state = ref.watch(availableOrdersProvider);
                final isLoading = state.isAccepting && state.acceptingOrderId == order.id;
                return TextButton(
                  onPressed: isLoading ? null : () async {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final deliveryPrice = double.tryParse(priceController.text);
                    if (deliveryPrice == null || deliveryPrice <= 0) {
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    _acceptOrder(order, deliveryPrice);
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

  /// [deliveryPrice] is null when the order already carries a price set by the
  /// admin — the captain was never asked, so nothing is sent and the backend
  /// keeps the existing price.
  void _acceptOrder(OrderModel order, double? deliveryPrice) async {
    final notifier = ref.read(availableOrdersProvider.notifier);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final success = await notifier.acceptOrder(order.id, deliveryPrice: deliveryPrice);

    if (!mounted) return;

    if (success) {
      scaffoldMessenger.showSnackBar(
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
      Navigator.of(context).pop();
    } else {
      final error = ref.read(availableOrdersProvider).error;
      scaffoldMessenger.showSnackBar(
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
  }
}