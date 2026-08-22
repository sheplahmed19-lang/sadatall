import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/order.dart';
import '../../services/user_order_service.dart';

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

  final UserOrderService _orderService = UserOrderService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill description with original order description
    _descriptionController.text = widget.order.description;
    // Pre-fill price if available
    if (widget.order.price > 0) {
      _priceController.text = widget.order.price.toStringAsFixed(2);
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

      // TODO: Counter offers are vendor functionality, not available for users
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('العروض المقابلة غير متاحة للمستخدمين'),
          backgroundColor: Colors.orange));
      Navigator.pop(context, null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red));
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
            title: const Text('عرض مقابل',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            backgroundColor: Colors.blue[700],
            elevation: 0),
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
                      _buildActionButtons()
                    ]))));
  }

  Widget _buildOrderSummaryCard() {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.receipt, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                Text('ملخص الطلب #${widget.order.id}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))
              ]),
              const SizedBox(height: 16),

              // Customer info
              if (widget.order.user != null) ...[
                _buildInfoRow(Icons.person, 'العميل', widget.order.user!.name),
                const SizedBox(height: 8)
              ],
              _buildInfoRow(Icons.phone, 'الهاتف', widget.order.phoneNumber),
              const SizedBox(height: 8),
              _buildInfoRow(
                  Icons.location_on, 'العنوان', widget.order.userAddress),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Original request
              const Text('الطلب الأصلي:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).dividerColor)),
                  child: Text(widget.order.description,
                      style: const TextStyle(fontSize: 14, height: 1.4))),

              if (widget.order.additionalNotes != null &&
                  widget.order.additionalNotes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('ملاحظات العميل:',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!)),
                    child: Text(widget.order.additionalNotes!,
                        style: const TextStyle(fontSize: 14, height: 1.4)))
              ]
            ])));
  }

  Widget _buildCounterOfferForm() {
    return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.attach_money, color: Colors.green[700], size: 24),
                const SizedBox(width: 12),
                const Text('عرضك المقابل',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ]),
              const SizedBox(height: 20),

              // Price field
              TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                  ],
                  decoration: InputDecoration(
                      labelText: 'السعر (ج.م)',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: '0.00',
                      hintTextDirection: TextDirection.ltr,
                      prefixIcon:
                          Icon(Icons.attach_money, color: Colors.green[700]),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.green[700]!, width: 2))),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال السعر';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'يرجى إدخال سعر صحيح';
                    }
                    return null;
                  }),

              const SizedBox(height: 16),

              // Description field
              TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                      labelText: 'وصف العرض',
                      labelStyle: const TextStyle(color: Colors.grey),
                      hintText: 'اكتب تفاصيل ما ستقدمه للعميل...',
                      prefixIcon:
                          Icon(Icons.description, color: Colors.blue[700]),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.blue[700]!, width: 2)),
                      alignLabelWithHint: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال وصف العرض';
                    }
                    if (value.trim().length < 10) {
                      return 'يجب أن يكون الوصف 10 أحرف على الأقل';
                    }
                    return null;
                  }),

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
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: Colors.orange[700]!, width: 2)),
                      alignLabelWithHint: true)),

              const SizedBox(height: 16),

              // Info box
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!)),
                  child: Row(children: [
                    Icon(Icons.info, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'سيتم إرسال عرضك للعميل وانتظار موافقته عليه.',
                            style: TextStyle(
                                fontSize: 14, color: Colors.blue[700])))
                  ]))
            ])));
  }

  Widget _buildActionButtons() {
    return Column(children: [
      SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
              onPressed: _isLoading ? null : _sendCounterOffer,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Icon(Icons.send, size: 20),
                          SizedBox(width: 8),
                          Text('إرسال العرض المقابل',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold))
                        ]))),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: const Text('إلغاء',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500))))
    ]);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: Colors.grey[600], size: 18),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey)),
      Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 14)))
    ]);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
