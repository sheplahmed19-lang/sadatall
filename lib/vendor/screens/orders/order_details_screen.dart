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
import '../../widgets/common/clickable_phone_field.dart';
import '../../widgets/common/clickable_phone_text.dart';
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

  /// Kept in step with the counter-offer screen's options so both ways of
  /// accepting an order offer the vendor the same choices.
  static const List<int> _waitingTimeOptions = [5, 10, 15, 20, 25, 30, 60];

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
    // Same waiting-time question the counter-offer flow asks, so an order
    // accepted at its existing price still tells the captain when to come.
    final result = await _showAcceptOrderDialog();

    if (result == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _orderService.acceptOrder(
        _order.id,
        waitingTime: result.waitingTime,
      );

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

  /// Confirms accepting the order at its current price and collects the
  /// waiting time. Returns null when the vendor cancels.
  Future<_AcceptOrderResult?> _showAcceptOrderDialog() async {
    // Carry over a waiting time the order already has, but only when it is one
    // of the offered values — the dropdown asserts its value is in `items`.
    final existing = _order.waitingTime;
    int? selectedWaitingTime =
        existing != null && _waitingTimeOptions.contains(existing)
            ? existing
            : null;

    return showDialog<_AcceptOrderResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('قبول الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('هل أنت متأكد من قبول هذا الطلب بالسعر الحالي؟'),
              const SizedBox(height: 20),
              const Text(
                'وقت الانتظار',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: selectedWaitingTime,
                isExpanded: true,
                decoration: const InputDecoration(
                  hintText: 'اختر الوقت التقديري لتجهيز الطلب',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                items: _waitingTimeOptions
                    .map(
                      (minutes) => DropdownMenuItem<int>(
                        value: minutes,
                        child: Text('$minutes دقيقة'),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedWaitingTime = value),
              ),
              const SizedBox(height: 8),
              Text(
                'يظهر للكابتن حتى يعرف موعد الاستلام.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                _AcceptOrderResult(waitingTime: selectedWaitingTime),
              ),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('قبول'),
            ),
          ],
        ),
      ),
    );
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  _buildCustomerInfoCard(),
                  if (_order.captain != null) ...[_buildCaptainInfoCard()],
                  _buildOrderDetailsCard(),
                  if (_order.orderItems != null &&
                      _order.orderItems!.isNotEmpty) ...[
                    _buildOrderItemsCard(),
                  ],
                  if (_order.attachments != null &&
                      _order.attachments!.isNotEmpty) ...[
                    _buildAttachmentsCard(),
                  ],
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
    final statusColor = _getStatusColor(_order.status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasTotal =
        _order.displayPrice != null &&
        _order.deliveryPrice != null &&
        _order.deliveryPrice != 0;
    final total = (_order.displayPrice ?? 0) + (_order.deliveryPrice ?? 0);

    return _panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getStatusIcon(_order.status),
                  size: 34,
                  color: statusColor,
                ),
                const SizedBox(height: 8),
                Text(
                  OrderStatus.getStatusDisplayName(_order.status),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          if (_order.displayPrice != null || _order.deliveryPrice != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  _buildPriceDetail(
                    _order.price != null && _order.price != 0
                        ? 'السعر'
                        : 'السعر المطلوب (تقديري)',
                    _order.displayPrice,
                    Colors.green,
                  ),
                  _buildPriceDetail(
                    'مصاريف التوصيل',
                    _order.deliveryPrice,
                    Colors.orange,
                  ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      const Text(
                        'الإجمالي',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        hasTotal
                            ? '${total.toStringAsFixed(2)} ج.م'
                            : 'غير محدد',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: hasTotal
                              ? (isDark
                                    ? Colors.lightBlue[200]
                                    : Colors.blue[700])
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (_order.price == null || _order.price == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'لم يتم تحديد سعر نهائي بعد من قبل المتجر',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Renders the description as a bulleted list when it spans several lines,
  /// and as plain text when it is a single line. Every line still goes
  /// through ClickablePhoneText so embedded phone numbers stay actionable.
  Widget _buildDescriptionBody() {
    const style = TextStyle(fontSize: 15, height: 1.45);
    final lines = _order.description
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return Text(
        'لا يوجد وصف',
        style: TextStyle(fontSize: 15, color: Colors.grey[600]),
      );
    }

    if (lines.length == 1) {
      return ClickablePhoneText(
        text: lines.first,
        style: const TextStyle(fontSize: 16, height: 1.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClickablePhoneText(text: line, style: style),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Shared shell for every section on this screen: a flat bordered panel
  /// rather than a drop-shadowed Card, so a long scroll reads as one surface
  /// instead of a stack of floating boxes.
  Widget _panel({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      padding: padding,
      child: child,
    );
  }

  /// Section heading used at the top of each panel.
  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.person, 'معلومات العميل', Colors.blue),
          _buildInfoRow(Icons.person, 'الاسم', _displayCustomerName()),
          _buildInfoRow(
            Icons.phone,
            'رقم الهاتف',
            _order.phoneNumber,
            isPhone: true,
            copyable: true,
          ),
          _buildInfoRow(
            Icons.location_on,
            'العنوان',
            _order.userAddress,
            copyable: true,
          ),
          if (_neighborhoodName != null) ...[
            _buildInfoRow(Icons.location_city, 'المنطقة', _neighborhoodName!),
          ],
          if (_order.vendorId != -1 && _neighborhoodName != null) ...[
            _buildInfoRow(
              Icons.alt_route,
              'المسار',
              'من ${_vendorLocationLabel()} إلى $_neighborhoodName',
            ),
          ],
        ],
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
    final hasPhoto =
        captain.photoUrl != null && captain.photoUrl!.trim().isNotEmpty;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.delivery_dining, 'معلومات الكابتن', Colors.green),

          // Identity block: avatar, name and rating together. The detail rows
          // used to be squeezed into an Expanded beside the photo, which left
          // their fixed-width labels fighting the values for space.
          Row(
            children: [
              GestureDetector(
                onTap: hasPhoto
                    ? () => _showFullImage(context, captain.photoUrl!)
                    : null,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withValues(alpha: 0.12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasPhoto
                      ? SmartImage(
                          imageSource: captain.photoUrl!,
                          fit: BoxFit.cover,
                        )
                      : Icon(Icons.person, size: 28, color: Colors.green[700]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      captain.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 15),
                        const SizedBox(width: 4),
                        Text(
                          rating > 0
                              ? rating.toStringAsFixed(1)
                              : 'لا يوجد تقييم',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ratingCount > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '($ratingCount)',
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

          const SizedBox(height: 12),

          // Phone gets its own full-width row so the number has room to
          // breathe, with call/copy grouped at the end.
          Row(
            children: [
              Icon(
                Icons.phone,
                size: 18,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClickablePhoneField(phoneNumber: captain.phoneNumber),
              ),
              InkWell(
                onTap: _callCaptain,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.call, color: Colors.green[700], size: 18),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openCaptainLocation,
              icon: const Icon(Icons.location_on, size: 18),
              label: const Text('عرض الموقع على الخريطة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red[700],
                side: BorderSide(color: Colors.red[300]!),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.receipt_long, 'تفاصيل الطلب', Colors.orange),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color.fromARGB(26, 191, 185, 185)
                  : const Color.fromARGB(255, 0, 0, 0),
              borderRadius: BorderRadius.circular(8),
            ),
            // Descriptions are usually a hand-written list, one item per
            // line; as a single block they read as a wall of text. Each line
            // becomes its own bulleted row, still via ClickablePhoneText so
            // phone numbers stay tappable / long-press copyable.
            child: _buildDescriptionBody(),
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
              _order.additionalNotes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            // Notes sit in a tinted panel with the label inline, rather than
            // a second bold sub-heading plus its own bordered box — that
            // nesting made the section read as two competing cards. The tint
            // is theme-aware so it does not stay cream-coloured in dark mode.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.14
                      : 0.08,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    color: Colors.orange[700],
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ملاحظات إضافية',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _order.additionalNotes!,
                          style: const TextStyle(fontSize: 14, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return _panel(
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
    );
  }

  Widget _buildOrderItemTile(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white10
            : Colors.grey[100],
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
    return _panel(
      child: AttachmentDisplayWidget(attachments: _order.attachments!),
    );
  }

  Widget _buildTimelineCard() {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.timeline, 'التوقيت', Colors.teal),
          _buildTimelineItem(
            Icons.add_circle,
            'تم إنشاء الطلب',
            TimeUtils.formatCairoTZDateTime(
              _order.createdAt,
              format: 'dd/MM/yyyy - hh:mm a',
            ),
            true,
          ),
          if (_order.updatedAt != null && _order.updatedAt != _order.createdAt)
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
    bool copyable = false,
  }) {
    final muted = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[400]!
        : Colors.grey[600]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: muted, size: 18),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isPhone ? _callCustomer : null,
              child: Text(
                value,
                // No explicit colour: inherits the theme so it stays legible
                // in dark mode. Only phone numbers are tinted, to signal that
                // they are tappable.
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isPhone ? Colors.blue[400] : null,
                  decoration: isPhone ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
          // The copy affordance used to sit on every row, which crowded the
          // card; it is now opt-in for the values worth copying.
          if (copyable)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ النص إلى الحافظة'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.copy, color: muted, size: 16),
              ),
            ),
        ],
      ),
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
    final isValid = price != null && price != 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[400]
                  : Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            isValid ? '${price.toStringAsFixed(2)} ج.م' : 'غير محدد',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isValid ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// What the vendor chose in the accept-order dialog. A returned instance means
/// "accept"; null (dialog dismissed) means the vendor backed out.
class _AcceptOrderResult {
  const _AcceptOrderResult({this.waitingTime});

  /// Minutes until the order is ready for pickup, or null if not specified.
  final int? waitingTime;
}
