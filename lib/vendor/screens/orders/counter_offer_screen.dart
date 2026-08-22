import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/common/clickable_phone_field.dart';
import '../../../captain/core/widgets/clickable_phone_text.dart'
    show ClickablePhoneText;

class CounterOfferScreen extends StatefulWidget {
  final Order order;

  const CounterOfferScreen({super.key, required this.order});

  @override
  State<CounterOfferScreen> createState() => _CounterOfferScreenState();
}

class _CounterOfferScreenState extends State<CounterOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  final OrderService _orderService = OrderService();
  bool _isLoading = false;

  /// How long the vendor needs before the order is ready for pickup. Shown to
  /// the captain as "الوقت التقديري" on the available/current order screens so
  /// they know whether to head over now or take another job first.
  int? _selectedWaitingTime;

  static const List<int> _waitingTimeOptions = [5, 10, 15, 20, 25, 30, 60];

  @override
  void initState() {
    super.initState();
    // Pre-fill description with original order description
    _descriptionController.text = widget.order.description;
    // Pre-fill price if available or parse from description
    double? initialPrice = widget.order.price;

    // Try to parse total from description if it exists in the specific format
    // Format: ...\n-----\nالإجمالي: 123 ج.م
    if (widget.order.description.isNotEmpty) {
      try {
        final lines = widget.order.description.trim().split('\n');
        if (lines.isNotEmpty) {
          final lastLine = lines.last.trim();
          if (lastLine.startsWith('الإجمالي:') && lastLine.contains('ج.م')) {
            final priceString = lastLine
                .replaceAll('الإجمالي:', '')
                .replaceAll('ج.م', '')
                .trim();
            final parsedPrice = double.tryParse(priceString);
            if (parsedPrice != null && parsedPrice > 0) {
              initialPrice = parsedPrice;
            }
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    if (initialPrice != null && initialPrice > 0) {
      _priceController.text = initialPrice.toStringAsFixed(2);
    }

    // Carry over a waiting time the order already has, but only if it is one
    // of the offered values — the dropdown asserts its value is in `items`.
    final existing = widget.order.waitingTime;
    if (existing != null && _waitingTimeOptions.contains(existing)) {
      _selectedWaitingTime = existing;
    }
  }

  Future<void> _sendCounterOffer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final price = double.parse(_priceController.text);
      final description = _descriptionController.text.trim();
      final notes = _notesController.text.trim();

      final response = await _orderService.sendCounterOffer(
        orderId: widget.order.id,
        description: description,
        price: price,
        additionalNotes: notes.isNotEmpty ? notes : null,
        waitingTime: _selectedWaitingTime,
      );

      if (response.success && response.data != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إرسال العرض بنجاح'),
              backgroundColor: Colors.green,
            ),
          );

          // Return the updated order to the previous screen
          Navigator.pop(context, response.data);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في إرسال العرض'),
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
      // No explicit background: grey[50] forced a near-white page even in dark
      // mode, so every theme-coloured (light) label on this screen ended up
      // invisible. Letting the theme supply it fixes the whole screen at once.
      appBar: AppBar(
        title: const Text(
          'عرض',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOrderSummaryCard(),
              const SizedBox(height: 16),
              _buildCounterOfferForm(),
              const SizedBox(height: 24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummaryCard() {
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
                Text(
                  'ملخص الطلب #${widget.order.id}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Customer info
            if (widget.order.user != null) ...[
              _buildInfoRow(Icons.person, 'العميل', widget.order.user!.name),
              const SizedBox(height: 8),
            ],
            _buildPhoneRow(Icons.phone, 'الهاتف', widget.order.phoneNumber),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.location_on,
              'العنوان',
              widget.order.userAddress,
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Original request
            const Text(
              'الطلب الأصلي:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Was grey[100]/grey[300]: a fixed light panel that in dark
                // mode held theme-coloured (light) text, making the
                // description unreadable.
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: ClickablePhoneText(
                text: widget.order.description,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ),

            if (widget.order.additionalNotes != null &&
                widget.order.additionalNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'ملاحظات العميل:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // Keep the orange accent, but as a translucent tint over
                  // whatever surface is behind it rather than a solid
                  // orange[50] that only works on a light background.
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.45),
                  ),
                ),
                child: ClickablePhoneText(
                  text: widget.order.additionalNotes!,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCounterOfferForm() {
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
                Icon(Icons.attach_money, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'عرضك',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Price field
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: 'السعر (ج.م)',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: '0.00',
                hintTextDirection: TextDirection.ltr,
                prefixIcon: Icon(Icons.attach_money, color: Colors.green[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال السعر';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'يرجى إدخال سعر صحيح';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Description field
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'وصف العرض',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'اكتب تفاصيل ما ستقدمه للعميل...',
                prefixIcon: Icon(Icons.description, color: Colors.blue[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue[700]!, width: 2),
                ),
                alignLabelWithHint: true,
              ),
              // validator: (value) {
              //   if (value == null || value.trim().isEmpty) {
              //     return 'يرجى إدخال وصف العرض';
              //   }
              //   return null;
              // }
            ),

            const SizedBox(height: 16),

            // Notes field
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'ملاحظات إضافية (اختياري)',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'أي ملاحظات أو تفاصيل إضافية...',
                prefixIcon: Icon(Icons.note, color: Colors.orange[700]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
                ),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // How long until the order is ready for pickup. The backend
            // already stored waitingTime on a counter offer and all three
            // captain order screens render it as "الوقت التقديري" — only this
            // form never asked for it, so it always arrived null.
            DropdownButtonFormField<int>(
              initialValue: _selectedWaitingTime,
              decoration: InputDecoration(
                labelText: 'مدة تجهيز الطلب (اختياري)',
                labelStyle: const TextStyle(color: Colors.grey),
                hintText: 'كم دقيقة حتى يصبح الطلب جاهزاً؟',
                prefixIcon: Icon(
                  Icons.timer_outlined,
                  color: Colors.purple[700],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.purple[700]!, width: 2),
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

            const SizedBox(height: 16),

            // Info box
            Builder(
              builder: (context) {
                // blue[700] text on a solid blue[50] panel is a light-mode-only
                // pairing. A translucent tint plus a brightness-aware ink keeps
                // the same "informational blue" reading in both themes.
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final infoInk = isDark ? Colors.blue[200]! : Colors.blue[700]!;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: infoInk, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم إرسال عرضك للعميل وانتظار موافقته عليه.',
                          style: TextStyle(fontSize: 14, color: infoInk),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendCounterOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
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
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'تاكيد السعر',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'تاكيد الطلب للعميل',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.normal,
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
              // grey[700] label + grey[300] border is a light-mode pairing:
              // both washed out against the dark surface.
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
              side: BorderSide(color: Theme.of(context).dividerColor),
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

  Widget _buildPhoneRow(IconData icon, String label, String phoneNumber) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 8),
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
          icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: phoneNumber));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم نسخ رقم الهاتف'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        Expanded(child: ClickablePhoneField(phoneNumber: phoneNumber)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
      ],
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
