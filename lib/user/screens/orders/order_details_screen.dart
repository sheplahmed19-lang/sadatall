import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../services/user_order_service.dart';
import '../../services/captain_service.dart';
import '../../services/location_service.dart';
import '../../utils/time_utils.dart';
import '../../widgets/attachments/attachment_display_widget.dart';
import '../../widgets/common/smart_image.dart';
import '../../../captain/core/widgets/clickable_phone_text.dart'
    show ClickablePhoneText;
import '../chat/order_chat_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final UserOrderService _orderService = UserOrderService();
  final CaptainService _captainService = CaptainService();
  final LocationService _locationService = LocationService();
  late Order _order;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    // _loadCaptainStats();
  }

  // Future<void> _loadCaptainStats() async {
  //   if (_order.captain?.id != null) {
  //     try {
  //       final response =
  //           await _captainService.getCaptainStats(_order.captain!.id);
  //       if (response.success && response.data != null) {
  //         setState(() {
  //           _captainStats = response.data;
  //         });
  //       }
  //     } catch (e) {
  //       // Handle error silently for now
  //     }
  //   }
  // }

  Future<void> _callVendor() async {
    final phoneUrl = Uri.parse('tel:${_order.vendor!.contactNumber}');
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
    // First, fetch the captain's current location
    if (_order.captain?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('معلومات الكابتن غير متوفرة'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await _captainService.getCaptainLocation(_order.captain!.id);

      setState(() {
        _isLoading = false;
      });

      if (response.success && response.data != null) {
        final location = response.data!;

        // Use the fetched coordinates for captain (source) and user destination (destination)
        final captainLat = location.latitude;
        final captainLng = location.longitude;

        // Always get current location to use coordinates instead of address text
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'خدمة تحديد المواقع غير مفعلة. لا يمكن تحديد موقعك الحالي.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Exit gracefully
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'تم رفض إذن تحديد المواقع. لا يمكن تحديد موقعك الحالي.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return; // Exit gracefully
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'تم رفض إذن تحديد المواقع بشكل دائم. يرجى تفعيل الإذن من إعدادات التطبيق.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Exit gracefully
        }

        // Get current location
        Position position;
        String destination;
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );

          // Use current location coordinates directly in the URL
          destination = '${position.latitude},${position.longitude}';
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('فشل في جلب موقعك الحالي: ${e.toString()}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Exit gracefully
        }

        // Use the user coordinates as destination - we'll use a URL that shows directions
        // This will open Google Maps with directions from captain location to user coordinates
        final List<String> mapUrls = [
          'https://www.google.com/maps/dir/?api=1&origin=$captainLat,$captainLng&destination=$destination&travelmode=driving',
          'https://www.google.com/maps/dir/$captainLat,$captainLng/$destination',
          'https://maps.google.com/?saddr=$captainLat,$captainLng&daddr=$destination',
          'geo:$captainLat,$captainLng?q=$destination',
        ];

        bool launched = false;
        String lastError = '';

        for (String urlString in mapUrls) {
          try {
            final uri = Uri.parse(urlString);
            ('Trying to launch: $urlString');

            if (await canLaunchUrl(uri)) {
              ('canLaunchUrl returned true for: $urlString');
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              launched = true;
              ('Successfully launched: $urlString');
              break;
            } else {
              ('canLaunchUrl returned false for: $urlString');
            }
          } catch (e) {
            lastError = e.toString();
            ('Error with URL $urlString: $e');
          }
        }

        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('لا يمكن فتح خرائط جوجل\nآخر خطأ: $lastError'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في جلب موقع الكابتن'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ('General error in _openCaptainLocation: $e');
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

  Future<void> _cancelOrder() async {
    final confirmed = await _showConfirmDialog(
      'إلغاء الطلب',
      'هل أنت متأكد من إلغاء هذا الطلب؟',
    );

    if (!confirmed) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _orderService.deleteOrder(_order.id.toString());

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return to previous screen
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'فشل في إلغاء الطلب'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  Future<void> _showRatingDialog() async {
    int selectedRating = 5; // Default rating

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('تقييم الكابتن'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('يرجى تقييم الكابتن من 1 إلى 5 نجوم'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final rating = index + 1;
                    return IconButton(
                      icon: Icon(
                        rating <= selectedRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                        size: 32,
                      ),
                      onPressed: () {
                        setState(() {
                          selectedRating = rating;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '$selectedRating/5',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _submitRating(selectedRating);
                },
                child: const Text('إرسال التقييم'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitRating(int rating) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await _orderService.rateOrder(_order.id.toString(), rating);

      if (response.success) {
        // Update the order's isRated property to true immediately
        setState(() {
          _order = _order.copyWith(isRated: true);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال التقييم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'فشل في إرسال التقييم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
            title: Text(
              title,
            ),
            content: Text(
              message,
            ),
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
      appBar: AppBar(
        title: Text(
          'طلب #${_order.id}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          if (_order.captain != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              tooltip: 'محادثة مع الكابتن',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OrderChatScreen(
                    orderId: _order.id.toString(),
                    captainId: _order.captain!.id,
                    captainName: _order.captain!.userName,
                    orderStatus: _order.status,
                  ),
                ));
              },
            ),
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: _callVendor,
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
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AttachmentDisplayWidget(
                          attachments: _order.attachments!,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildTimelineCard(),
                  const SizedBox(
                      height: 100), // Space for floating action button
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
              statusColor.withOpacity(0.05)
            ],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              _getStatusIcon(_order.status),
              size: 48,
              color: statusColor,
            ),
            const SizedBox(height: 12),
            Text(
              OrderStatus.getStatusDisplayName(_order.status),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (_order.hasAnyPrice) ...[
              // Check if both prices are strictly greater than zero to show total
              if (_order.price > 0 && (_order.deliveryPrice != null && _order.deliveryPrice! > 0)) ...[
                // Show total price only when BOTH prices are valid (> 0)
                const SizedBox(height: 8),
                Text(
                  'الإجمالي: ${_order.totalPrice!.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ] else ...[
                 // If either price is missing or zero, show placeholder for Total
                 const SizedBox(height: 8),
                 Text(
                   'الإجمالي: -- ج.م',
                   style: const TextStyle(
                     fontSize: 24,
                     fontWeight: FontWeight.bold,
                     color: Colors.green, // Keep green as style, or change to grey if preferred
                   ),
                 ),
              ],
              
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'الطلب: ${_order.price > 0 ? '${_order.price.toStringAsFixed(2)} ج.م' : '--'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'التوصيل: ${_order.deliveryPrice != null && _order.deliveryPrice! > 0 ? '${_order.deliveryPrice!.toStringAsFixed(2)} ج.م' : '--'}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],

            // How long the vendor said it needs to prepare the order. Only set
            // once the vendor has accepted or sent an offer, so it doubles as
            // a sign the order is actually being worked on.
            if (_order.waitingTime != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 18, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      'وقت التجهيز: ${_order.waitingTime} دقيقة',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ],
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_order.user != null) ...[
              _buildInfoRow(Icons.person, 'الاسم', _order.user!.name),
              const SizedBox(height: 12),
            ],
            _buildInfoRow(Icons.phone, 'رقم الهاتف', _order.phoneNumber,
                isPhone: true),
            if (_order.neighborhood != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                  Icons.location_city, 'المنطقة', _order.neighborhood!.name),
            ],
            const SizedBox(height: 12),
            _buildInfoRow(
                Icons.store,
                'المتجر',
                _order.vendorId == -1
                    ? 'طلب مخصص'
                    : (_order.vendor?.vendorName ?? 'متجر غير محدد')),
            if (_order.vendor != null && _order.vendor!.contactNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.phone_outlined, 'رقم هاتف المتجر', _order.vendor!.contactNumber,
                  isPhone: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaptainInfoCard() {
    final captain = _order.captain!;

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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Captain photo and name
            Row(
              children: [
                // Captain photo
                if (captain.photoUrl != null)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.green[700]!,
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: SmartImage(
                        imageSource: captain.photoUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                      border: Border.all(
                        color: Colors.green[700]!,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey[600],
                    ),
                  ),
                const SizedBox(width: 16),
                // Captain name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الاسم',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        captain.userName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

            // Show location button only if order is not delivered
            if (_order.status != OrderStatus.delivered) ...[
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

            // Show rating button or rated message only for delivered orders
            if (_order.status == OrderStatus.delivered) ...[
              const SizedBox(height: 16),
              if (_order.isRated) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'تم تقييم هذا الطلب',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showRatingDialog,
                    icon: const Icon(Icons.star),
                    label: const Text('تقييم الكابتن'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ClickablePhoneText(
                text: _order.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
            if (_order.additionalNotes != null &&
                _order.additionalNotes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.note, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'ملاحظات إضافية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
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
                child: ClickablePhoneText(
                  text: _order.additionalNotes!,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              Icons.add_circle,
              'تم إنشاء الطلب',
              TimeUtils.formatCairoDateTimeArabic(_order.createdAt,
                  pattern: 'dd/MM/yyyy - hh:mm a'),
              true,
            ),
            if (_order.updatedAt != null &&
                _order.updatedAt != _order.createdAt)
              _buildTimelineItem(
                Icons.update,
                'آخر تحديث',
                TimeUtils.formatCairoDateTimeArabic(_order.updatedAt!,
                    pattern: 'dd/MM/yyyy - hh:mm a'),
                false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
      IconData icon, String title, String time, bool isFirst) {
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {bool isPhone = false}) {
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
        Expanded(
          child: GestureDetector(
            onTap: isPhone ? _callVendor : null,
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

  Widget? _buildActionButtons() {
    List<Widget> buttons = [];

    switch (_order.status) {
      case OrderStatus.pending:
      case OrderStatus.counterOfferAccepted:
        buttons = [
          FloatingActionButton.extended(
            heroTag: 'order_details_cancel_fab',
            onPressed: _cancelOrder,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('إلغاء الطلب'),
          ),
        ];
        break;
    }

    if (buttons.isEmpty) return null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
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

}
