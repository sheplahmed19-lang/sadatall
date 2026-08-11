import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/captain_service.dart';
import '../../services/neighborhood_service.dart' show NeighborhoodService;
import 'counter_offer_screen.dart';
import '../../utils/time_utils.dart';
import '../../widgets/attachments/attachment_display_widget.dart';
import '../../widgets/common/smart_image.dart';
import '../chat/vendor_order_chat_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderService _orderService = OrderService();
  final CaptainService _captainService = CaptainService();
  final NeighborhoodService _neighborhoodService = NeighborhoodService();
  late Order _order;
  bool _isLoading = false;
  CaptainStats? _captainStats;
  String? _fallbackNeighborhoodName;

  @override
  void initState() {
    super.initState();
    _order = widget.order;

    // _loadCaptainStats();

    // The order's neighborhood relation may be missing on the object handed
    // to this screen (e.g. an older client build, or a response that didn't
    // include it) even though neighborhoodId is always present. Resolve the
    // name from the full neighborhoods list as a fallback so it still shows.
    if (_order.neighborhood == null && _order.neighborhoodId != 0) {
      _loadFallbackNeighborhoodName();
    }
  }

  String? get _neighborhoodName =>
      _order.neighborhood?.name ?? _fallbackNeighborhoodName;

  Future<void> _loadFallbackNeighborhoodName() async {
    final response = await _neighborhoodService.getNeighborhoods();
    if (!mounted || !response.success || response.data == null) return;

    final match = response.data!.where(
      (n) => n.id == _order.neighborhoodId.toString(),
    );
    if (match.isNotEmpty) {
      setState(() {
        _fallbackNeighborhoodName = match.first.name;
      });
    }
  }

  Future<void> _callCustomer() async {
    final phoneUrl = Uri.parse('tel:${_order.phoneNumber}');
    if (await canLaunchUrl(phoneUrl)) {
      await launchUrl(phoneUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن فتح تطبيق الهاتف'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _callCaptain() async {
    if (_order.captain?.phoneNumber != null) {
      final phoneUrl = Uri.parse('tel:${_order.captain!.phoneNumber}');
      if (await canLaunchUrl(phoneUrl)) {
        await launchUrl(phoneUrl);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن فتح تطبيق الهاتف'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openCaptainLocation() async {
    final captainId = _order.captain?.id;
    if (captainId == null || captainId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('معلومات الكابتن غير متوفرة'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Read the captain's live position instead of the hardcoded coordinates
    // that used to be here, which pinned every captain to the same spot.
    final locationResponse = await _captainService.getCaptainLocation(
      captainId,
    );
    if (!locationResponse.success || locationResponse.data == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locationResponse.error ?? 'فشل في تحديد موقع الكابتن',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final lat = locationResponse.data!.latitude;
    final lng = locationResponse.data!.longitude;

    if (lat == 0 && lng == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('موقع الكابتن غير متاح حالياً'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Try different URL formats for better compatibility
      final List<String> mapUrls = [
        'https://www.google.com/maps?q=$lat,$lng',
        'geo:$lat,$lng?q=$lat,$lng',
        'google.navigation:q=$lat,$lng',
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        'https://maps.google.com/?q=$lat,$lng',
      ];

      bool launched = false;
      String lastError = '';

      for (String urlString in mapUrls) {
        try {
          final uri = Uri.parse(urlString);

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;

            break;
          } else {}
        } catch (e) {
          lastError = e.toString();
        }
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لا يمكن فتح خرائط جوجل\\nآخر خطأ: $lastError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في فتح الخرائط: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendCounterOffer() async {
    final result = await Navigator.push<Order?>(
      context,
      MaterialPageRoute(
        builder: (context) => CounterOfferScreen(order: _order),
      ),
    );

    if (result != null) {
      setState(() {
        _order = result;
      });
    }
  }

  Future<void> _acceptOrder() async {
    final confirmed = await _showConfirmDialog(
      'قبول الطلب',
      'هل أنت متأكد من قبول هذا الطلب بالسعر الحالي؟',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _orderService.acceptOrder(_order.id);

      if (response.success && response.data != null) {
        setState(() {
          _order = response.data!;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم قبول الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في قبول الطلب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _rejectOrder() async {
    final confirmed = await _showConfirmDialog(
      'رفض الطلب',
      'هل أنت متأكد من رفض هذا الطلب؟\\nلن تتمكن من التراجع عن هذا القرار.',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _orderService.rejectOrder(_order.id);

      if (response.success && response.data != null) {
        setState(() {
          _order = response.data!;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في رفض الطلب'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'طلب #${_order.id}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        actions: [
          if (_order.captain != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              tooltip: 'محادثة مع الكابتن',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VendorOrderChatScreen(
                      orderId: _order.id.toString(),
                      captainId: _order.captain!.id,
                      captainName: _order.captain!.userName,
                      orderStatus: _order.status,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _callCustomer,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 16),
                  _buildCustomerInfoCard(),
                  const SizedBox(height: 16),
                  if (_order.captain != null) ...[
                    _buildCaptainInfoCard(),
                    const SizedBox(height: 16),
                  ],
                  _buildOrderDetailsCard(),
                  if (_order.orderItems != null &&
                      _order.orderItems!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildOrderItemsCard(),
                  ],
                  if (_order.attachments != null &&
                      _order.attachments!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildAttachmentsCard(),
                  ],
                  const SizedBox(height: 16),
                  _buildTimelineCard(),
                  const SizedBox(
                    height: 100,
                  ), // Space for floating action button
                ],
              ),
            ),
      floatingActionButton: _buildActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusCard() {
    Color statusColor = _getStatusColor(_order.status);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              statusColor.withOpacity(0.1),
              statusColor.withOpacity(0.05),
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(_getStatusIcon(_order.status), size: 48, color: statusColor),
            const SizedBox(height: 12),
            Text(
              OrderStatus.getStatusDisplayName(_order.status),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            // Price and delivery price
            if (_order.displayPrice != null ||
                _order.deliveryPrice != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _buildPriceDetail(
                      _order.price != null && _order.price != 0
                          ? 'السعر:'
                          : 'السعر المطلوب (تقديري):',
                      _order.displayPrice,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: _buildPriceDetail(
                      'مصاريف التوصيل:',
                      _order.deliveryPrice,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Total price
              Text(
                'الإجمالي: ${_order.displayPrice == null || _order.deliveryPrice == null || _order.deliveryPrice == 0 ? '--' : '${(_order.displayPrice! + _order.deliveryPrice!).toStringAsFixed(2)} ج.م'}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              if (_order.price == null || _order.price == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'لم يتم تحديد سعر نهائي بعد من قبل المتجر',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'معلومات العميل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.person, 'الاسم', _displayCustomerName()),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.phone,
              'رقم الهاتف',
              _order.phoneNumber,
              isPhone: true,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'العنوان', _order.userAddress),
            if (_neighborhoodName != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.location_city, 'المنطقة', _neighborhoodName!),
            ],
            if (_order.vendorId != -1 && _neighborhoodName != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                Icons.alt_route,
                'المسار',
                'من ${_vendorLocationLabel()} إلى $_neighborhoodName',
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _vendorLocationLabel() {
    final vendor = _order.vendor;
    if (vendor == null) return 'المتجر';
    final neighborhoodName = vendor.neighborhoodName;
    if (neighborhoodName != null && neighborhoodName.isNotEmpty) {
      return '$neighborhoodName - ${vendor.address}';
    }
    return vendor.address;
  }

  Widget _buildCaptainInfoCard() {
    final captain = _order.captain!;
    final rating = _captainStats?.currentRating ?? captain.currentRating ?? 0.0;
    final ratingCount = _captainStats?.totalRatings ?? captain.ratingCount ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.delivery_dining, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'معلومات الكابتن',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (captain.photoUrl != null &&
                    captain.photoUrl!.trim().isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => _showFullImage(context, captain.photoUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: SmartImage(
                          imageSource: captain.photoUrl!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Captain name
                      _buildInfoRow(Icons.person, 'الاسم', captain.userName),
                      const SizedBox(height: 12),

                      // Captain phone with call action
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 12),
                          const Text(
                            'رقم الهاتف: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _callCaptain,
                              child: Text(
                                captain.phoneNumber,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _callCaptain,
                            icon: Icon(Icons.phone, color: Colors.green[700]),
                            tooltip: 'اتصال بالكابتن',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Rating
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 12),
                          const Text(
                            'التقييم: ',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${rating.toStringAsFixed(1)} ⭐',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                          if (ratingCount > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '($ratingCount تقييم)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Location button (always show with 0,0 coordinates for now)
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openCaptainLocation,
                icon: const Icon(Icons.location_on),
                label: const Text('عرض الموقع على الخريطة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[300]!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'تفاصيل الطلب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                _order.description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            if (_order.waitingTime != null) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                Icons.access_time,
                'وقت الانتظار',
                '${_order.waitingTime} دقيقة',
              ),
            ],
            if (_order.additionalNotes != null &&
                _order.additionalNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.note, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'ملاحظات إضافية',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Text(
                  _order.additionalNotes!,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Text(
                  'عناصر الطلب (${_order.orderItems!.length})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._order.orderItems!.map((item) => _buildOrderItemTile(item)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'الإجمالي',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_order.orderItems!.fold(0.0, (sum, item) => sum + (item.price * item.quantity)).toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Quantity badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blue[700],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                item.quantity.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menu?.name ?? 'عنصر غير معروف',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item.notes != null && item.notes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.notes!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          // Price
          Text(
            '${(item.price * item.quantity).toStringAsFixed(2)} ج.م',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AttachmentDisplayWidget(attachments: _order.attachments!),
      ),
    );
  }

  Widget _buildTimelineCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'التوقيت',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              Icons.add_circle,
              'تم إنشاء الطلب',
              TimeUtils.formatCairoTZDateTime(
                _order.createdAt,
                format: 'dd/MM/yyyy - hh:mm a',
              ),
              true,
            ),
            if (_order.updatedAt != null &&
                _order.updatedAt != _order.createdAt)
              _buildTimelineItem(
                Icons.update,
                'آخر تحديث',
                TimeUtils.formatCairoTZDateTime(
                  _order.updatedAt!,
                  format: 'dd/MM/yyyy - hh:mm a',
                ),
                false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    IconData icon,
    String title,
    String time,
    bool isFirst,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: isFirst ? 12 : 0),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayCustomerName() {
    // For send-package orders, the sender's name (which may differ from the
    // account owner) is embedded in additionalNotes as "الاسم: <name>".
    // Prefer that when present; fall back to the account's registered name.
    final notes = _order.additionalNotes;
    if (notes != null) {
      final match = RegExp(r'الاسم:\s*(.+)').firstMatch(notes);
      final senderName = match?.group(1)?.trim();
      if (senderName != null && senderName.isNotEmpty) {
        return senderName;
      }
    }
    return _order.user?.name ?? 'غير محدد';
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isPhone = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        // add copy icon
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نسخ النص إلى الحافظة'),
                backgroundColor: Colors.green,
              ),
            );
          },
          icon: Icon(Icons.copy, color: Colors.grey[600], size: 20),
          tooltip: 'نسخ',
        ),
        Expanded(
          child: GestureDetector(
            onTap: isPhone ? _callCustomer : null,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isPhone ? Colors.blue[700] : Colors.black87,
                decoration: isPhone ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black87,
            child: Stack(
              children: [
                Center(
                  child: SmartImage(imageSource: imageUrl, fit: BoxFit.contain),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget? _buildActionButtons() {
    List<Widget> buttons = [];

    switch (_order.status) {
      case OrderStatus.pending:
        buttons = [
          FloatingActionButton.extended(
            heroTag: 'reject_order_fab',
            onPressed: _rejectOrder,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.close),
            label: const Text('رفض الطلب'),
          ),
          FloatingActionButton.extended(
            heroTag: 'counter_offer_fab',
            onPressed: _sendCounterOffer,
            backgroundColor: Colors.green,
            icon: const Icon(Icons.attach_money),
            label: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تاكيد السعر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'تاكيد الطلب للعميل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
          if (_order.price != null && _order.price != 0)
            FloatingActionButton.extended(
              heroTag: 'accept_order_fab',
              onPressed: _acceptOrder,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.check),
              label: const Text('قبول'),
            ),
        ];
        break;
    }

    if (buttons.isEmpty) return null;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: buttons,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.counterOfferSent:
        return Colors.blue;
      case OrderStatus.counterOfferAccepted:
        return Colors.green;
      case OrderStatus.acceptedByCaptain:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.counterOfferSent:
        return Icons.attach_money;
      case OrderStatus.counterOfferAccepted:
        return Icons.check_circle;
      case OrderStatus.acceptedByCaptain:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Widget _buildPriceDetail(String label, double? price, Color color) {
    // Check if price is null or 0
    bool isValid = price != null && price != 0;
    return Text(
      '$label ${isValid ? '${price!.toStringAsFixed(2)} ج.م' : '--'}',
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color),
    );
  }
}
