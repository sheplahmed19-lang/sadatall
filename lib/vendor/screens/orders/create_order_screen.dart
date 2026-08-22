import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../models/attachment.dart';
import '../../widgets/attachments/attachment_list_widget.dart';
import '../../widgets/common/neighborhood_dropdown.dart';

class CreateOrderScreen extends StatefulWidget {
  /// When true this is the shop's own order (طلب شخصي للمتجر): it is delivered
  /// to the vendor itself, so no customer phone/address/neighbourhood is asked
  /// for — those are taken from the vendor's own profile instead.
  final bool isShopOrder;

  const CreateOrderScreen({super.key, this.isShopOrder = false});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _priceController = TextEditingController();
  // Second contact for this order specifically (e.g. the employee handling
  // it), shown to the captain alongside the shop's registered number.
  final _extraPhoneController = TextEditingController();
  final OrderService _orderService = OrderService();
  bool _isLoading = false;
  String? _selectedNeighborhoodId;
  int? _selectedWaitingTime;
  List<Attachment> _attachments = [];

  /// Attachment object keys are namespaced per draft order. The order does not
  /// exist yet, so this stands in until the backend assigns a real id.
  late final String _draftOrderId =
      'vendor_${DateTime.now().millisecondsSinceEpoch}';

  static const List<int> _waitingTimeOptions = [5, 10, 15, 20, 25, 30, 60];

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      var vendor = auth.currentVendor;

      // A shop order is delivered to the shop, so its destination comes from
      // the vendor's own profile rather than from fields the vendor fills in.
      //
      // currentVendor can be null while the vendor is still perfectly logged
      // in: checkAuthStatus() deliberately stays authenticated when the
      // launch-time profile fetch fails (no connectivity on the splash
      // screen, or a cache read that didn't parse), and leaves screens to
      // recover. So refetch here instead of failing the whole order.
      if (widget.isShopOrder && vendor == null) {
        await auth.ensureVendorLoaded();
        vendor = auth.currentVendor;
      }

      if (widget.isShopOrder && vendor == null) {
        throw Exception(
          'تعذر تحميل بيانات المتجر، تحقق من الاتصال بالإنترنت وحاول مرة أخرى',
        );
      }

      final neighborhoodId = widget.isShopOrder
          ? int.parse(vendor!.neighborhoodId)
          : int.parse(_selectedNeighborhoodId!);
      final description = _descriptionController.text.trim();
      final notes = _notesController.text.trim();
      final address = widget.isShopOrder
          ? vendor!.address
          : _addressController.text.trim();
      final phone = widget.isShopOrder
          ? vendor!.contactNumber
          : (_phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : 'غير محدد');
      final priceText = _priceController.text.trim();
      final price = priceText.isNotEmpty ? double.tryParse(priceText) : null;

      // The order carries a single phoneNumber column, so a second contact
      // rides along in the notes. Both the captain and vendor order screens
      // render notes through ClickablePhoneText, which turns any number in
      // that text into a tap-to-call/copy link — so this stays usable rather
      // than being buried prose.
      final extraPhone = _extraPhoneController.text.trim();
      final notesWithExtraPhone = extraPhone.isEmpty
          ? notes
          : (notes.isEmpty
                ? 'رقم هاتف إضافي: $extraPhone'
                : '$notes\nرقم هاتف إضافي: $extraPhone');

      final response = await _orderService.createOrderByVendor(
        description: description,
        additionalNotes: notesWithExtraPhone.isNotEmpty
            ? notesWithExtraPhone
            : null,
        userAddress: address,
        phoneNumber: phone,
        neighborhoodId: neighborhoodId,
        price: price,
        waitingTime: _selectedWaitingTime,
        attachments: _attachments.isNotEmpty ? _attachments : null,
      );

      if (response.success && response.data != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الطلب بنجاح'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context, response.data);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في إنشاء الطلب'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isShopOrder ? 'طلب للمتجر' : 'إنشاء طلب جديد',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoCard(context),
              const SizedBox(height: 16),
              // A shop order goes to the shop itself, so there is no customer
              // to describe — the destination comes from the vendor profile.
              if (!widget.isShopOrder) ...[
                _buildCustomerInfoCard(context),
                const SizedBox(height: 16),
              ],
              _buildOrderDetailsCard(context),
              const SizedBox(height: 24),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.add_business,
              size: 48,
              color: isDark ? Colors.blue[200] : Colors.blue[700],
            ),
            const SizedBox(height: 12),
            Text(
              widget.isShopOrder ? 'طلب شخصي للمتجر' : 'إنشاء طلب للعميل',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.blue[200] : Colors.blue[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.isShopOrder
                  ? 'اطلب احتياجات المتجر وسيتم توصيلها إلى عنوان متجرك'
                  : 'قم بإنشاء طلب نيابة عن العميل وإرساله إليه',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.blue[100] : Colors.blue[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuildContext context) {
    final labelColor = Theme.of(context).textTheme.bodySmall?.color;
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
            const SizedBox(height: 20),

            // Phone field
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                labelStyle: TextStyle(color: labelColor),
                hintText: '+201234567890',
                hintTextDirection: TextDirection.ltr,
                prefixIcon: Icon(Icons.phone, color: Colors.green[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Address field
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                labelText: 'عنوان التوصيل (اختياري)',
                labelStyle: TextStyle(color: labelColor),
                hintText: 'اكتب العنوان الكامل للتوصيل...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: Icon(Icons.location_on, color: Colors.red[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.red[700]!, width: 2),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // Neighborhood dropdown. Only reachable for customer orders —
            // this whole card is hidden for shop orders, which take the
            // vendor's own neighbourhood instead.
            NeighborhoodDropdown(
              selectedNeighborhoodId: _selectedNeighborhoodId,
              onChanged: (value) {
                setState(() {
                  _selectedNeighborhoodId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى اختيار المنطقة';
                }
                return null;
              },
              labelText: 'المنطقة',
              prefixIcon: Icon(Icons.location_city, color: Colors.purple[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetailsCard(BuildContext context) {
    final labelColor = Theme.of(context).textTheme.bodySmall?.color;
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
                Icon(Icons.receipt_long, color: Colors.orange[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'تفاصيل الطلب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Price and estimated time apply to a customer order. A shop
            // order is the shop buying something for itself, so it has no
            // customer-facing price to quote.
            if (!widget.isShopOrder) ...[
              TextFormField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'السعر (ج.م) - اختياري',
                  labelStyle: TextStyle(color: labelColor),
                  hintText: 'أدخل السعر الإجمالي للطلب...',
                  hintTextDirection: TextDirection.rtl,
                  prefixIcon: Icon(
                    Icons.attach_money,
                    color: Colors.green[700],
                  ),
                  suffixText: 'ج.م',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final price = double.tryParse(value);
                    if (price == null || price < 0) {
                      return 'يرجى إدخال سعر صحيح';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedWaitingTime,
                decoration: InputDecoration(
                  labelText: 'الوقت التقديري للتوصيل (اختياري)',
                  labelStyle: TextStyle(color: labelColor),
                  hintText: 'اختر الوقت التقديري',
                  prefixIcon: Icon(
                    Icons.timer_outlined,
                    color: Colors.blue[700],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                  ),
                ),
                items: _waitingTimeOptions
                    .map(
                      (minutes) => DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes دقيقة'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedWaitingTime = v),
              ),
            ],
            const SizedBox(height: 16),

            // Description is optional for a customer order — the vendor often
            // has the details on the phone already. It stays required for a
            // shop order, where it is the only thing telling the captain what
            // to buy.
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.isShopOrder
                    ? 'وصف الطلب'
                    : 'وصف الطلب (اختياري)',
                labelStyle: TextStyle(color: labelColor),
                hintText: 'اكتب تفاصيل الطلب المطلوب...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: Icon(Icons.description, color: Colors.orange[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
                ),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (!widget.isShopOrder) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال وصف الطلب';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Notes field
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                labelStyle: TextStyle(color: labelColor),
                hintText: 'أي ملاحظات أو تفاصيل إضافية...',
                hintTextDirection: TextDirection.rtl,
                prefixIcon: Icon(Icons.note, color: Colors.teal[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.teal[700]!, width: 2),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // Extra contact for this order — appended to the notes on submit,
            // since the order carries only one phone column.
            TextFormField(
              controller: _extraPhoneController,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                labelText: 'رقم هاتف إضافي (اختياري)',
                labelStyle: TextStyle(color: labelColor),
                hintText: '01xxxxxxxxx',
                prefixIcon: Icon(Icons.phone, color: Colors.blue[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                ),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return null; // optional
                if (v.length < 7) return 'رقم الهاتف غير صحيح';
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Photos + voice note. The widget uploads to Wasabi as files are
            // picked and hands back the object keys, so by submit time there
            // is nothing left to wait for.
            Row(
              children: [
                Icon(Icons.attach_file, color: Colors.purple[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'المرفقات (اختياري)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AttachmentListWidget(
              orderId: _draftOrderId,
              attachments: _attachments,
              onAttachmentsChanged: (updated) {
                setState(() => _attachments = updated);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final outlineColor = Theme.of(context).dividerColor;
    final outlineTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'إرسال الطلب',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: outlineTextColor,
              side: BorderSide(color: outlineColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'إلغاء',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _notesController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _priceController.dispose();
    _extraPhoneController.dispose();
    super.dispose();
  }
}
