import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/clickable_phone_text.dart';
import '../../../../core/utils/app_utils.dart';
import '../../data/models/order_model.dart';
import '../widgets/order_attachments_widget.dart';

class DeliveredOrderDetailsScreen extends StatelessWidget {
  final OrderModel order;

  const DeliveredOrderDetailsScreen({Key? key, required this.order})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #${order.id}'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.delivered.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.delivered.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.delivered),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم تسليم هذا الطلب',
                      style: TextStyle(
                        color: AppColors.delivered,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    _buildDetailRow('رقم الطلب:', '#${order.id}'),
                    if (order.vendorId != '-1')
                      _buildDetailRow('المتجر:', order.vendorName),
                    if (order.vendor?.contactNumber != null)
                      _buildPhoneDetailRow(
                        'هاتف المتجر:',
                        order.vendor!.contactNumber,
                      ),
                    if (order.routeLabel != null)
                      _buildDetailRow('المسار:', order.routeLabel!),
                    _buildDetailRowWithClickablePhones(
                      'وصف الطلب:',
                      order.description,
                    ),
                    _buildDetailRow('اسم العميل:', _displayCustomerName()),
                    _buildDetailRow(
                      'الحي:',
                      order.neighborhood?.name ?? 'غير محدد',
                    ),
                    _buildDetailRow('عنوان العميل:', order.userAddress),
                    _buildPhoneDetailRow('رقم الهاتف:', order.phoneNumber),
                    if (order.price != null)
                      _buildDetailRow(
                        'سعر الطلب:',
                        AppUtils.formatPrice(order.price!),
                      ),
                    if (order.deliveryPrice != null)
                      _buildDetailRow(
                        'سعر التوصيل:',
                        AppUtils.formatPrice(order.deliveryPrice!),
                      ),
                    if (order.waitingTime != null)
                      _buildDetailRow(
                        'وقت الانتظار:',
                        '${order.waitingTime} دقيقة',
                      ),
                    _buildDetailRow(
                      'وقت الطلب:',
                      AppUtils.formatDateTime(order.createdAt.toLocal()),
                    ),
                    if (order.acceptedByCapta != null)
                      _buildDetailRow(
                        'وقت قبول الكابتن:',
                        AppUtils.formatDateTime(
                          order.acceptedByCapta!.toLocal(),
                        ),
                      ),
                    if (order.deliveredAt != null)
                      _buildDetailRow(
                        'وقت التسليم:',
                        AppUtils.formatDateTime(order.deliveredAt!.toLocal()),
                      ),
                    if (order.additionalNotes != null &&
                        order.additionalNotes!.isNotEmpty)
                      _buildDetailRowWithClickablePhones(
                        'ملاحظات:',
                        order.additionalNotes!,
                      ),
                    if (order.attachments != null &&
                        order.attachments!.isNotEmpty)
                      OrderAttachmentsWidget(attachments: order.attachments!),
                  ],
                ),
              ),
            ),
            if (order.userLatitude != null && order.userLongitude != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _openInMaps(
                  context,
                  order.userLatitude!,
                  order.userLongitude!,
                ),
                icon: const Icon(Icons.map),
                label: const Text('عرض موقع العميل على الخريطة'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _displayCustomerName() {
    final notes = order.additionalNotes;
    if (notes != null) {
      final match = RegExp(r'الاسم:\s*(.+)').firstMatch(notes);
      final senderName = match?.group(1)?.trim();
      if (senderName != null && senderName.isNotEmpty) {
        return senderName;
      }
    }
    return order.user?.userName ?? 'غير محدد';
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
            width: 110,
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

  Widget _buildDetailRowWithClickablePhones(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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

  void _openInMaps(BuildContext context, double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن فتح تطبيق الخرائط')),
        );
      }
    }
  }
}
