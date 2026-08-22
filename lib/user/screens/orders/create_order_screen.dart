import 'package:flutter/material.dart';
import '../../models/vendor.dart';
import '../../models/user.dart';
import '../../models/attachment.dart';
import '../../services/user_order_service.dart';
import '../../services/location_service.dart';
import '../../services/storage_service.dart';
import '../../services/cart_service.dart';
import '../../services/user_vendor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../widgets/common/neighborhood_dropdown.dart';
import '../../widgets/attachments/attachment_list_widget.dart';
import '../../utils/validators.dart';

class CreateOrderScreen extends StatefulWidget {
  final Vendor? vendor;
  final bool isCustomOrder;
  final bool isCheckout;
  final bool isSendPackage;

  const CreateOrderScreen({
    super.key,
    this.vendor,
    this.isCustomOrder = false,
    this.isCheckout = false,
    this.isSendPackage = false,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _additionalNotesController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  // Controllers for package sender/receiver info
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _senderAddressController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _receiverAddressController = TextEditingController();

  final _orderService = UserOrderService();
  final _locationService = LocationService();
  final _cartService = CartService();
  final _vendorService = UserVendorService();

  bool _isLoading = false;
  bool _isLoadingLocation = false;
  bool _isLoadingDeliveryPrice = false;
  double? _latitude;
  double? _longitude;
  String? _selectedNeighborhoodId;
  double _deliveryPrice = 0.0;
  List<Attachment> _attachments = [];
  late String _orderId;

  @override
  void initState() {
    super.initState();
    // Generate a unique order ID for attachments
    _orderId = DateTime.now().millisecondsSinceEpoch.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForm();
    });
  }

  Future<void> _initializeForm() async {
    final storageService = StorageService();
    final user = await storageService.getUserData();

    if (user != null && mounted) {
      // Check mounted to prevent setState after dispose
      setState(() {
        // Prefill the form fields with user profile data
        _phoneNumberController.text = user.phoneNumber;
        _senderNameController.text = user.userName;
        _senderPhoneController.text = user.phoneNumber;
        _selectedNeighborhoodId = user.neighborhoodId;

        // If in send package mode, set fixed description
        if (widget.isSendPackage) {
          _descriptionController.text = 'طرد مرسل';
        }
        // If in checkout mode, populate description from cart
        else if (widget.isCheckout) {
          _descriptionController.text = _cartService.getCartDescription();
        }
      });

      // Fetch delivery price for initial neighborhood if in checkout mode
      if (widget.isCheckout &&
          user.neighborhoodId != null &&
          widget.vendor != null) {
        await _fetchDeliveryPrice(user.neighborhoodId!);
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _additionalNotesController.dispose();
    _phoneNumberController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _senderAddressController.dispose();
    _receiverPhoneController.dispose();
    _receiverAddressController.dispose();
    super.dispose();
  }

  /// Empties the whole cart after confirmation, and clears the description
  /// that was generated from it so the order text stays in sync.
  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إفراغ السلة'),
        content: const Text('هل تريد حذف كل العناصر من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('حذف الكل'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    _cartService.clearCart();
    setState(() {
      _descriptionController.text = '';
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إفراغ السلة')));
  }

  Future<void> _fetchDeliveryPrice(String neighborhoodId) async {
    if (!widget.isCheckout || widget.vendor == null) {
      return;
    }

    setState(() {
      _isLoadingDeliveryPrice = true;
    });

    try {
      final result = await _vendorService.getVendorPricing(
        vendorId: widget.vendor!.id,
        neighborhoodId: neighborhoodId,
      );

      if (mounted) {
        setState(() {
          _isLoadingDeliveryPrice = false;
          if (result.success && result.data != null) {
            _deliveryPrice = result.data!;
          } else {
            _deliveryPrice = 0.0;
            // Optionally show error to user
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.error ?? 'فشل في تحميل سعر التوصيل'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDeliveryPrice = false;
          _deliveryPrice = 0.0;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final result = await _locationService.getCurrentLocation();

      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        if (result.success) {
          setState(() {
            _latitude = result.latitude;
            _longitude = result.longitude;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم الحصول على الموقع بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'فشل في الحصول على الموقع'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: \${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedNeighborhoodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الحي'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String vendorId;
      if (widget.isCustomOrder || widget.isSendPackage) {
        vendorId = '-1';
      } else {
        vendorId = widget.vendor!.id;
      }

      // Build additional notes from sender/receiver info if in send package mode
      String additionalNotes;
      String phoneNumber;

      if (widget.isSendPackage) {
        final packageNote = _additionalNotesController.text.trim();
        additionalNotes =
            'من (المرسل):\n'
            'الاسم: ${_senderNameController.text.trim()}\n'
            'رقم الهاتف: ${_senderPhoneController.text.trim()}\n'
            'العنوان: ${_senderAddressController.text.trim()}\n\n'
            'إلى (المستلم):\n'
            'رقم الهاتف: ${_receiverPhoneController.text.trim()}\n'
            'العنوان: ${_receiverAddressController.text.trim()}'
            '${packageNote.isNotEmpty ? '\n\nملاحظة: $packageNote' : ''}';
        phoneNumber = _senderPhoneController.text
            .trim(); // Use sender's phone for the order
      } else {
        additionalNotes = _additionalNotesController.text.trim();
        phoneNumber = _phoneNumberController.text.trim();
      }

      final result = await _orderService.createOrder(
        vendorId: vendorId,
        description: _descriptionController.text.trim(),
        price: _cartService.getTotalItemsPrice(),
        additionalNotes: additionalNotes,
        userAddress: '', // Empty for compatibility
        phoneNumber: phoneNumber,
        userLatitude: _latitude ?? 0.0, // Default to 0 if not provided
        userLongitude: _longitude ?? 0.0, // Default to 0 if not provided
        neighborhoodId: _selectedNeighborhoodId!,
        attachments: _attachments.isNotEmpty ? _attachments : null,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? 'تم إنشاء الطلب بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'فشل إنشاء الطلب'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: \${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isSendPackage
              ? 'ارسال طرد'
              : widget.isCustomOrder
              ? 'طلب مخصص'
              : 'طلب جديد',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'جاري إنشاء الطلب...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vendor Info Card (if not custom order)
                if (!widget.isCustomOrder && widget.vendor != null) ...[
                  Card(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppTheme.primaryColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المتجر المحدد',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.vendor!.vendorName,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (widget.vendor!.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.vendor!.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Order Description
                if (widget.isCheckout) ...[
                  // Info text for checkout mode
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'وصف الطلب (تم إنشاؤه تلقائياً من العناصر المحددة)',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                CustomTextField(
                  label: 'وصف الطلب',
                  hint: widget.isCheckout
                      ? 'العناصر المحددة'
                      : widget.isSendPackage
                      ? 'طرد مرسل'
                      : 'أدخل تفاصيل ما تريد طلبه',
                  controller: _descriptionController,
                  prefixIcon: Icons.description,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  enabled:
                      !widget.isCheckout &&
                      !widget
                          .isSendPackage, // Read-only in checkout and send package mode
                ),
                const SizedBox(height: 16),

                // Additional Notes or Package Details
                if (widget.isSendPackage) ...[
                  // Sender Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'من (المرسل)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'اسم المرسل *',
                          hint: 'أدخل اسم المرسل',
                          controller: _senderNameController,
                          prefixIcon: Icons.person,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'اسم المرسل مطلوب';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'رقم هاتف المرسل *',
                          hint: 'أدخل رقم هاتف المرسل',
                          controller: _senderPhoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'رقم هاتف المرسل مطلوب';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'عنوان المرسل *',
                          hint: 'أدخل عنوان المرسل بالتفصيل',
                          controller: _senderAddressController,
                          prefixIcon: Icons.location_on,
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'عنوان المرسل مطلوب';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        NeighborhoodDropdown(
                          selectedNeighborhoodId: _selectedNeighborhoodId,
                          onChanged: (value) {
                            setState(() {
                              _selectedNeighborhoodId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'يرجى اختيار الحي';
                            }
                            return null;
                          },
                          labelText: 'الحي',
                          prefixIcon: Icon(
                            Icons.location_city,
                            color: Colors.purple[700],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Location picker for sender
                        const Divider(),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'الموقع الدقيق للمرسل (اختياري)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_latitude != null && _longitude != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.successColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'تم تحديد الموقع بنجاح',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: AppTheme.warningColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'لم يتم تحديد الموقع بعد',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: 'تحديد الموقع الحالي',
                          onPressed: _getCurrentLocation,
                          isLoading: _isLoadingLocation,
                          type: ButtonType.outline,
                          icon: Icons.my_location,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receiver Information
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'إلى (المستلم)',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          label: 'رقم هاتف المستلم *',
                          hint: 'أدخل رقم هاتف المستلم',
                          controller: _receiverPhoneController,
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'رقم هاتف المستلم مطلوب';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        CustomTextField(
                          label: 'عنوان المستلم *',
                          hint: 'أدخل عنوان المستلم بالتفصيل',
                          controller: _receiverAddressController,
                          prefixIcon: Icons.location_on,
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'عنوان المستلم مطلوب';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Optional note for the package
                  CustomTextField(
                    label: 'ملاحظة (اختياري)',
                    hint: 'أي ملاحظات أو تعليمات خاصة بالطرد',
                    controller: _additionalNotesController,
                    prefixIcon: Icons.note,
                    maxLines: 2,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  CustomTextField(
                    label: 'ملاحظات إضافية',
                    hint: 'أي ملاحظات أو طلبات خاصة',
                    controller: _additionalNotesController,
                    prefixIcon: Icons.note,
                    maxLines: 2,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone Number (not shown in send package mode)
                if (!widget.isSendPackage) ...[
                  CustomTextField(
                    label: 'رقم الهاتف *',
                    hint: 'أدخل رقم هاتفك',
                    controller: _phoneNumberController,
                    keyboardType: TextInputType.phone,
                    prefixIcon: Icons.phone,
                    validator: Validators.validatePhoneNumber,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                ],

                // Neighborhood Selection (not shown in send package mode - it's in sender section)
                if (!widget.isSendPackage) ...[
                  NeighborhoodDropdown(
                    selectedNeighborhoodId: _selectedNeighborhoodId,
                    onChanged: (value) {
                      setState(() {
                        _selectedNeighborhoodId = value;
                      });
                      // Fetch delivery price when neighborhood changes in checkout mode
                      if (widget.isCheckout && value != null) {
                        _fetchDeliveryPrice(value);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى اختيار الحي';
                      }
                      return null;
                    },
                    labelText: 'الحي',
                    prefixIcon: Icon(
                      Icons.location_city,
                      color: Colors.purple[700],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Location Section (not shown in send package mode - it's in sender section)
                if (!widget.isSendPackage) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.my_location,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'الموقع الدقيق (اختياري)',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_latitude != null && _longitude != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: AppTheme.successColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'تم تحديد الموقع بنجاح',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.successColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning,
                                  color: AppTheme.warningColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'لم يتم تحديد الموقع بعد',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        CustomButton(
                          text: 'تحديد الموقع الحالي',
                          onPressed: _getCurrentLocation,
                          isLoading: _isLoadingLocation,
                          type: ButtonType.outline,
                          icon: Icons.my_location,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Attachments Section (every order type except cart checkout,
                // which has its own cart-based flow)
                if (!widget.isCheckout) ...[
                  AttachmentListWidget(
                    orderId: _orderId,
                    attachments: _attachments,
                    onAttachmentsChanged: (newAttachments) {
                      setState(() {
                        _attachments = newAttachments;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Cart Summary (only in checkout mode)
                if (widget.isCheckout) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shopping_cart,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ملخص السلة',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const Spacer(),
                            if (_cartService.isNotEmpty)
                              TextButton.icon(
                                onPressed: _confirmClearCart,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.errorColor,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                label: const Text('إفراغ السلة'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Cart items list (only if not empty)
                        if (_cartService.isNotEmpty) ...[
                          ..._cartService.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.sizeName != null
                                          ? '${item.name} (${item.sizeName}) x${item.quantity}'
                                          : '${item.name} x${item.quantity}',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  Text(
                                    '${item.subtotal.toStringAsFixed(0)} جنيه',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),

                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),

                          // Total items price
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'إجمالي العناصر',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_cartService.getTotalItemsPrice().toStringAsFixed(0)} جنيه',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Delivery price (always show)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'سعر التوصيل',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_isLoadingDeliveryPrice) ...[
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              '${_deliveryPrice.toStringAsFixed(0)} جنيه',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        // Total price (only if cart has items)
                        if (_cartService.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(thickness: 2),
                          const SizedBox(height: 8),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الإجمالي الكلي',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                '${(_cartService.getTotalItemsPrice() + _deliveryPrice).toStringAsFixed(0)} جنيه',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Info note
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber[800],
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'السعر الإجمالي للعناصر أعلاه (لا يشمل الإضافات الأخرى)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.amber[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 16),

                // Create Order Button
                CustomButton(
                  text: 'إنشاء الطلب',
                  onPressed: _createOrder,
                  isLoading: _isLoading,
                  height: 52,
                  icon: Icons.add_shopping_cart,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
