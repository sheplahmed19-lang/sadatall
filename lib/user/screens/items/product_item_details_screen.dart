import 'package:flutter/material.dart';
import '../../models/product_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/smart_image.dart';

class ProductItemDetailsScreen extends StatefulWidget {
  final ProductItem productItem;
  final bool isEditable;

  const ProductItemDetailsScreen({
    super.key,
    required this.productItem,
    this.isEditable = false,
  });

  @override
  State<ProductItemDetailsScreen> createState() =>
      _ProductItemDetailsScreenState();
}

class _ProductItemDetailsScreenState extends State<ProductItemDetailsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late bool _isAvailable;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.productItem.name);
    _descriptionController =
        TextEditingController(text: widget.productItem.description);
    _priceController =
        TextEditingController(text: widget.productItem.price.toString());
    _isAvailable = widget.productItem.isAvailable;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditable ? 'تفاصيل المنتج' : widget.productItem.name),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (widget.isEditable)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: Colors.grey[200],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.productItem.imageUrl != null
                        ? SmartImage(
                            imageSource: widget.productItem.imageUrl!,
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

            // Product Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name
                  if (widget.isEditable)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اسم المنتج',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
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
                        ),
                      ],
                    )
                  else
                    Text(
                      widget.productItem.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Price
                  if (widget.isEditable)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'السعر',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
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
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.productItem.sizes.isEmpty
                              ? '${widget.productItem.price.toStringAsFixed(0)} جنيه'
                              : 'يبدأ من ${widget.productItem.sizes.map((s) => s.effectivePrice).reduce((a, b) => a < b ? a : b).toStringAsFixed(0)} جنيه',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                  // Sizes (read-only mode only — vendor edits these from
                  // the vendor app's own product form, not here)
                  if (!widget.isEditable && widget.productItem.sizes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'الأحجام المتاحة',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...widget.productItem.sizes.map(
                      (size) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                size.name,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: size.isAvailable ? AppTheme.textPrimary : Colors.grey,
                                ),
                              ),
                            ),
                            Text(
                              size.isAvailable
                                  ? '${size.effectivePrice.toStringAsFixed(0)} جنيه'
                                  : 'غير متاح',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: size.isAvailable ? AppTheme.primaryColor : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Availability Toggle (editable mode only)
                  if (widget.isEditable)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
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
                    ),

                  if (widget.isEditable) const SizedBox(height: 24),

                  // Description
                  if (widget.productItem.description.isNotEmpty)
                    Column(
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
                          TextField(
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
                          )
                        else
                          Text(
                            widget.productItem.description,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // Product Info Card (non-editable mode)
                  if (!widget.isEditable)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.inventory_2_outlined,
                            'رقم المنتج',
                            widget.productItem.id,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            Icons.check_circle_outline,
                            'الحالة',
                            widget.productItem.isAvailable ? 'متاح' : 'غير متاح',
                            valueColor: widget.productItem.isAvailable
                                ? AppTheme.successColor
                                : Colors.red,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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

  void _saveChanges() {
    // This method would be used in the vendor app to save changes
    // For now, just show a message and pop back
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم حفظ التغييرات بنجاح'),
        backgroundColor: AppTheme.successColor,
      ),
    );
    Navigator.of(context).pop();
  }
}
