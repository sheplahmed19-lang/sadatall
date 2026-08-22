// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// import '../../services/order_service.dart';
// import '../../widgets/common/neighborhood_dropdown.dart';

// class CreateOrderScreen extends StatefulWidget {
//   const CreateOrderScreen({super.key});

//   @override
//   State<CreateOrderScreen> createState() => _CreateOrderScreenState();
// }

// class _CreateOrderScreenState extends State<CreateOrderScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _descriptionController = TextEditingController();
//   final _notesController = TextEditingController();
//   final _addressController = TextEditingController();
//   final _phoneController = TextEditingController();
//   final _priceController = TextEditingController();
//   final OrderService _orderService = OrderService();
//   bool _isLoading = false;
//   String? _selectedNeighborhoodId;

//   Future<void> _createOrder() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final neighborhoodId = int.parse(_selectedNeighborhoodId!);
//       final description = _descriptionController.text.trim();
//       final notes = _notesController.text.trim();
//       final address = _addressController.text.trim();
//       final phone = _phoneController.text.trim();
//       final priceText = _priceController.text.trim();
//       final price = priceText.isNotEmpty ? double.tryParse(priceText) : null;

//       final response = await _orderService.createOrderByVendor(
//         description: description,
//         additionalNotes: notes.isNotEmpty ? notes : null,
//         userAddress: address,
//         phoneNumber: phone,
//         neighborhoodId: neighborhoodId,
//         price: price,
//       );

//       if (response.success && response.data != null) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(
//               content: Text('تم إنشاء الطلب بنجاح'),
//               backgroundColor: Colors.green,
//             ),
//           );

//           Navigator.pop(context, response.data);
//         }
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//               content: Text(response.error ?? 'فشل في إنشاء الطلب'),
//               backgroundColor: Colors.red,
//             ),
//           );
//         }
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('حدث خطأ: ${e.toString()}'),
//             backgroundColor: Colors.red,
//           ),
//         );
//       }
//     } finally {
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey[50],
//       appBar: AppBar(
//         title: const Text(
//           'إنشاء طلب جديد',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: Colors.white,
//           ),
//         ),
//         elevation: 0,
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.stretch,
//             children: [
//               _buildInfoCard(),
//               const SizedBox(height: 16),
//               _buildCustomerInfoCard(),
//               const SizedBox(height: 16),
//               _buildOrderDetailsCard(),
//               const SizedBox(height: 24),
//               _buildActionButtons(),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoCard() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(12),
//           gradient: LinearGradient(
//             colors: [Colors.blue[50]!, Colors.blue[50]!],
//             begin: Alignment.topRight,
//             end: Alignment.bottomLeft,
//           ),
//         ),
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             Icon(
//               Icons.add_business,
//               size: 48,
//               color: Colors.blue[700],
//             ),
//             const SizedBox(height: 12),
//             Text(
//               'إنشاء طلب للعميل',
//               style: TextStyle(
//                 fontSize: 20,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.blue[700],
//               ),
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'قم بإنشاء طلب نيابة عن العميل وإرساله إليه',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.blue[600],
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildCustomerInfoCard() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.person, color: Colors.blue[700], size: 24),
//                 const SizedBox(width: 12),
//                 const Text(
//                   'معلومات العميل',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             // Phone field
//             TextFormField(
//               controller: _phoneController,
//               keyboardType: TextInputType.phone,
//               textDirection: TextDirection.ltr,
//               decoration: InputDecoration(
//                 labelText: 'رقم الهاتف',
//                 labelStyle: const TextStyle(color: Colors.grey),
//                 hintText: '+201234567890',
//                 hintTextDirection: TextDirection.ltr,
//                 prefixIcon: Icon(Icons.phone, color: Colors.green[700]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.green[700]!, width: 2),
//                 ),
//               ),
//               validator: (value) {
//                 if (value == null || value.trim().isEmpty) {
//                   return 'يرجى إدخال رقم الهاتف';
//                 }
//                 if (value.trim().length < 10) {
//                   return 'رقم الهاتف قصير جداً';
//                 }
//                 return null;
//               },
//             ),

//             const SizedBox(height: 16),

//             // Address field
//             TextFormField(
//               controller: _addressController,
//               maxLines: 2,
//               textDirection: TextDirection.rtl,
//               decoration: InputDecoration(
//                 labelText: 'عنوان التوصيل',
//                 labelStyle: const TextStyle(color: Colors.grey),
//                 hintText: 'اكتب العنوان الكامل للتوصيل...',
//                 hintTextDirection: TextDirection.rtl,
//                 prefixIcon: Icon(Icons.location_on, color: Colors.red[700]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.red[700]!, width: 2),
//                 ),
//                 alignLabelWithHint: true,
//               ),
//               validator: (value) {
//                 if (value == null || value.trim().isEmpty) {
//                   return 'يرجى إدخال عنوان التوصيل';
//                 }
//                 return null;
//               },
//             ),

//             const SizedBox(height: 16),

//             // Neighborhood dropdown
//             NeighborhoodDropdown(
//               selectedNeighborhoodId: _selectedNeighborhoodId,
//               onChanged: (value) {
//                 setState(() {
//                   _selectedNeighborhoodId = value;
//                 });
//               },
//               validator: (value) {
//                 if (value == null || value.isEmpty) {
//                   return 'يرجى اختيار المنطقة';
//                 }
//                 return null;
//               },
//               labelText: 'المنطقة',
//               prefixIcon: Icon(Icons.location_city, color: Colors.purple[700]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOrderDetailsCard() {
//     return Card(
//       elevation: 2,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.receipt_long, color: Colors.orange[700], size: 24),
//                 const SizedBox(width: 12),
//                 const Text(
//                   'تفاصيل الطلب',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             // Price field
//             TextFormField(
//               controller: _priceController,
//               keyboardType: TextInputType.numberWithOptions(decimal: true),
//               inputFormatters: [
//                 FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
//               ],
//               decoration: InputDecoration(
//                 labelText: 'السعر (ج.م) - اختياري',
//                 labelStyle: const TextStyle(color: Colors.grey),
//                 hintText: 'أدخل السعر الإجمالي للطلب...',
//                 hintTextDirection: TextDirection.rtl,
//                 prefixIcon: Icon(Icons.attach_money, color: Colors.green[700]),
//                 suffixText: 'ج.م',
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.green[700]!, width: 2),
//                 ),
//               ),
//               validator: (value) {
//                 if (value != null && value.isNotEmpty) {
//                   final price = double.tryParse(value);
//                   if (price == null || price < 0) {
//                     return 'يرجى إدخال سعر صحيح';
//                   }
//                 }
//                 return null;
//               },
//             ),

//             const SizedBox(height: 16),

//             // // Description field
//             // TextFormField(
//             //   controller: _descriptionController,
//             //   maxLines: 4,
//             //   decoration: InputDecoration(
//             //     labelText: 'وصف الطلب',
//             //     labelStyle: const TextStyle(color: Colors.grey),
//             //     hintText: 'اكتب تفاصيل الطلب المطلوب...',
//             //     hintTextDirection: TextDirection.rtl,
//             //     prefixIcon: Icon(Icons.description, color: Colors.orange[700]),
//             //     border: OutlineInputBorder(
//             //       borderRadius: BorderRadius.circular(12),
//             //     ),
//             //     focusedBorder: OutlineInputBorder(
//             //       borderRadius: BorderRadius.circular(12),
//             //       borderSide: BorderSide(color: Colors.orange[700]!, width: 2),
//             //     ),
//             //     alignLabelWithHint: true,
//             //   ),
//             //   validator: (value) {
//             //     if (value == null || value.trim().isEmpty) {
//             //       return 'يرجى إدخال وصف الطلب';
//             //     }
//             //     return null;
//             //   },
//             // ),

//             // const SizedBox(height: 16),

//             // Notes field
//             TextFormField(
//               controller: _notesController,
//               maxLines: 3,
//               decoration: InputDecoration(
//                 labelText: 'ملاحظات إضافية (اختياري)',
//                 labelStyle: const TextStyle(color: Colors.grey),
//                 hintText: 'أي ملاحظات أو تفاصيل إضافية...',
//                 hintTextDirection: TextDirection.rtl,
//                 prefixIcon: Icon(Icons.note, color: Colors.teal[700]),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(12),
//                   borderSide: BorderSide(color: Colors.teal[700]!, width: 2),
//                 ),
//                 alignLabelWithHint: true,
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Info boxes
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.blue[50],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.blue[200]!),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.info, color: Colors.blue[700], size: 20),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'سيتم إرسال الطلب للعميل المحدد بحالة "في الانتظار".',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.blue[700],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 12),
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.orange[50],
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: Colors.orange[200]!),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.warning, color: Colors.orange[700], size: 20),
//                   const SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       'تأكد من صحة المعلومات قبل الإرسال.',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.orange[700],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildActionButtons() {
//     return Column(
//       children: [
//         SizedBox(
//           width: double.infinity,
//           height: 56,
//           child: ElevatedButton(
//             onPressed: _isLoading ? null : _createOrder,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.blue[700],
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               elevation: 2,
//             ),
//             child: _isLoading
//                 ? const SizedBox(
//                     width: 24,
//                     height: 24,
//                     child: CircularProgressIndicator(
//                       color: Colors.white,
//                       strokeWidth: 2,
//                     ),
//                   )
//                 : const Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.send, size: 20),
//                       SizedBox(width: 8),
//                       Text(
//                         'إرسال الطلب',
//                         style: TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//           ),
//         ),
//         const SizedBox(height: 12),
//         SizedBox(
//           width: double.infinity,
//           height: 56,
//           child: OutlinedButton(
//             onPressed: _isLoading ? null : () => Navigator.pop(context),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: Colors.grey[700],
//               side: BorderSide(color: Colors.grey[300]!),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12),
//               ),
//             ),
//             child: const Text(
//               'إلغاء',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _descriptionController.dispose();
//     _notesController.dispose();
//     _addressController.dispose();
//     _phoneController.dispose();
//     _priceController.dispose();
//     super.dispose();
//   }
// }
