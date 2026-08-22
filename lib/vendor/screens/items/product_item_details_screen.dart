import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/product_item.dart';
import '../../services/item_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/smart_image.dart';

class ProductItemDetailsScreen extends StatefulWidget {
  final ProductItem? productItem; // Null for create mode
  final bool isEditable;

  const ProductItemDetailsScreen({
    super.key,
    this.productItem,
    this.isEditable = false,
  });

  @override
  State<ProductItemDetailsScreen> createState() =>
      _ProductItemDetailsScreenState();
}

class _ProductItemDetailsScreenState extends State<ProductItemDetailsScreen> {
  final ItemService _itemService = ItemService();
  final ImagePicker _imagePicker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late bool _isAvailable;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isCreating = false; // True if creating new item

  final List<_SizeRowControllers> _sizeRows = [];

  @override
  void initState() {
    super.initState();
    _isCreating = widget.productItem == null;
    _nameController = TextEditingController(text: widget.productItem?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.productItem?.description ?? '');
    _priceController =
        TextEditingController(text: widget.productItem?.price.toString() ?? '');
    _isAvailable = widget.productItem?.isAvailable ?? true;

    for (final size in widget.productItem?.sizes ?? const []) {
      _sizeRows.add(_SizeRowControllers.fromSize(size));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    for (final row in _sizeRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addSizeRow() {
    setState(() => _sizeRows.add(_SizeRowControllers()));
  }

  void _removeSizeRow(int index) {
    setState(() {
      _sizeRows[index].dispose();
      _sizeRows.removeAt(index);
    });
  }

  /// Validates the size rows and returns the parsed list, or null (showing a
  /// SnackBar naming the failing row) if any row is invalid.
  List<ItemSizeOption>? _validateAndCollectSizes() {
    final sizes = <ItemSizeOption>[];

    for (var i = 0; i < _sizeRows.length; i++) {
      final row = _sizeRows[i];
      final name = row.nameController.text.trim();
      final priceText = row.priceController.text.trim();
      final discountText = row.discountPriceController.text.trim();

      if (name.isEmpty) {
        _showError('يرجى إدخال اسم الحجم رقم ${i + 1}');
        return null;
      }

      final price = double.tryParse(priceText);
      if (price == null) {
        _showError('يرجى إدخال سعر صحيح للحجم "$name"');
        return null;
      }

      double? discountPrice;
      if (discountText.isNotEmpty) {
        discountPrice = double.tryParse(discountText);
        if (discountPrice == null) {
          _showError('يرجى إدخال سعر خصم صحيح للحجم "$name"');
          return null;
        }
        if (discountPrice >= price) {
          _showError('سعر الخصم يجب أن يكون أقل من السعر الأصلي للحجم "$name"');
          return null;
        }
      }

      sizes.add(ItemSizeOption(
        id: row.id,
        name: name,
        price: price,
        discountPrice: discountPrice,
        isAvailable: row.isAvailable,
      ));
    }

    return sizes;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Lets the vendor photograph the product directly instead of only picking
  /// an existing file — most products are photographed on the spot.
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'اختر مصدر الصورة',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('الكاميرا'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('معرض الصور'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في اختيار الصورة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate image for new items
    if (_isCreating && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار صورة للمنتج'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final sizes = _validateAndCollectSizes();
    if (sizes == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = double.tryParse(_priceController.text) ?? 0.0;

      ApiResponse<ProductItem> response;

      if (_isCreating) {
        // Create new item - image is required
        response = await _itemService.createItem(
          image: _selectedImage!,
          name: name,
          description: description,
          price: price,
          isAvailable: _isAvailable,
          sizes: sizes,
        );
      } else {
        // Update existing item - image is optional
        response = await _itemService.updateItem(
          id: widget.productItem!.id,
          image: _selectedImage, // Can be null
          name: name,
          description: description,
          price: price,
          isAvailable: _isAvailable,
          sizes: sizes,
        );
      }

      if (response.success && response.data != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isCreating ? 'تم إضافة المنتج بنجاح' : 'تم حفظ التغييرات بنجاح',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.of(context).pop(response.data); // Return updated item
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في حفظ التغييرات'),
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteItem() async {
    if (_isCreating) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا المنتج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _itemService.deleteItem(widget.productItem!.id);

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المنتج بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate deletion
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.error ?? 'فشل في حذف المنتج'),
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isCreating
              ? 'إضافة منتج جديد'
              : (widget.isEditable ? 'تعديل المنتج' : widget.productItem!.name),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isEditable && !_isCreating)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _deleteItem,
            ),
          if (widget.isEditable)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isLoading ? null : _saveChanges,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Product Image
                    _buildImageSection(),

                    // Product Details
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Product Name
                          _buildNameField(theme),
                          const SizedBox(height: 16),

                          // Price
                          _buildPriceField(theme),
                          const SizedBox(height: 24),

                          // Sizes / variants (optional)
                          _buildSizesSection(theme),
                          const SizedBox(height: 24),

                          // Availability Toggle (editable mode only)
                          if (widget.isEditable) _buildAvailabilityToggle(theme),

                          if (widget.isEditable) const SizedBox(height: 24),

                          // Description
                          _buildDescriptionField(theme),

                          const SizedBox(height: 24),

                          // Product Info Card (non-editable mode)
                          if (!widget.isEditable && widget.productItem != null)
                            _buildProductInfoCard(),

                          // Save button (for editable mode)
                          if (widget.isEditable) ...[
                            const SizedBox(height: 24),
                            _buildSaveButton(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildImageSection() {
    return GestureDetector(
      onTap: widget.isEditable ? _showImageSourceSheet : null,
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.grey[200],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: _selectedImage != null
                  ? Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    )
                  : widget.productItem?.imageUrl != null
                      ? SmartImage(
                          imageSource: widget.productItem!.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.shopping_bag,
                            size: 100,
                            color: Colors.grey[500],
                          ),
                        ),
            ),
            // Change image button (editable mode)
            if (widget.isEditable)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  onPressed: _showImageSourceSheet,
                  backgroundColor: AppTheme.primaryColor,
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                ),
              ),
            // Availability badge
            if (!_isAvailable)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'غير متاح',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(ThemeData theme) {
    if (widget.isEditable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اسم المنتج',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال اسم المنتج';
              }
              return null;
            },
          ),
        ],
      );
    } else {
      return Text(
        widget.productItem!.name,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  Widget _buildPriceField(ThemeData theme) {
    if (widget.isEditable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'السعر',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixText: 'جنيه',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال السعر';
              }
              if (double.tryParse(value) == null) {
                return 'يرجى إدخال رقم صحيح';
              }
              return null;
            },
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(
            Icons.attach_money,
            color: AppTheme.primaryColor,
            size: 28,
          ),
          const SizedBox(width: 4),
          Text(
            '${widget.productItem!.price.toStringAsFixed(0)} جنيه',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSizesSection(ThemeData theme) {
    if (!widget.isEditable) {
      final sizes = widget.productItem?.sizes ?? const [];
      if (sizes.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الأحجام والأسعار',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (final size in sizes) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      size.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (size.discountPrice != null) ...[
                    Text(
                      '${size.price.toStringAsFixed(0)} جنيه',
                      style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${size.discountPrice!.toStringAsFixed(0)} جنيه',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else
                    Text(
                      '${size.price.toStringAsFixed(0)} جنيه',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (!size.isAvailable) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'غير متاح',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأحجام والأسعار (اختياري)',
          style: theme.textTheme.titleSmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _sizeRows.length; i++) ...[
          _buildSizeRow(i),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _addSizeRow,
          icon: const Icon(Icons.add),
          label: const Text('إضافة حجم جديد'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            side: const BorderSide(color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }

  Widget _buildSizeRow(int index) {
    final row = _sizeRows[index];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: row.nameController,
                  decoration: const InputDecoration(
                    labelText: 'الحجم',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _removeSizeRow(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.discountPriceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'السعر بعد الخصم (اختياري)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const Text('متوفر', style: TextStyle(fontSize: 12)),
                  Switch(
                    value: row.isAvailable,
                    onChanged: (value) =>
                        setState(() => row.isAvailable = value),
                    activeTrackColor: AppTheme.successColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'متاح للبيع',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: (value) {
              setState(() {
                _isAvailable = value;
              });
            },
            activeTrackColor: AppTheme.successColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوصف',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (widget.isEditable)
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'يرجى إدخال وصف المنتج';
              }
              return null;
            },
          )
        else
          Text(
            widget.productItem!.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
      ],
    );
  }

  Widget _buildProductInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            Icons.inventory_2_outlined,
            'رقم المنتج',
            widget.productItem!.id,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            Icons.check_circle_outline,
            'الحالة',
            widget.productItem!.isAvailable ? 'متاح' : 'غير متاح',
            valueColor: widget.productItem!.isAvailable
                ? AppTheme.successColor
                : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isCreating ? 'إضافة المنتج' : 'حفظ التغييرات',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SizeRowControllers {
  final String? id;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController discountPriceController;
  bool isAvailable;

  _SizeRowControllers({
    this.id,
    String name = '',
    String price = '',
    String discountPrice = '',
    this.isAvailable = true,
  })  : nameController = TextEditingController(text: name),
        priceController = TextEditingController(text: price),
        discountPriceController = TextEditingController(text: discountPrice);

  factory _SizeRowControllers.fromSize(ItemSizeOption size) {
    return _SizeRowControllers(
      id: size.id,
      name: size.name,
      price: size.price.toString(),
      discountPrice: size.discountPrice?.toString() ?? '',
      isAvailable: size.isAvailable,
    );
  }

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    discountPriceController.dispose();
  }
}
