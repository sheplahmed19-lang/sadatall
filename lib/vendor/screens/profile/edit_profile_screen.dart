import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sadat_delivery_merged/vendor/widgets/common/update_location_widget.dart';
import '../../providers/auth_provider.dart';
import '../../services/vendor_service.dart';
import '../../models/vendor.dart';
import '../../widgets/common/neighborhood_dropdown.dart';
import '../../widgets/common/category_selector.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final VendorService _vendorService = VendorService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  File? _selectedImage;
  Vendor? _currentVendor;
  String? _selectedNeighborhoodId;
  List<String> _selectedCategoryIds = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentVendorData();
  }

  void _loadCurrentVendorData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if vendor is locked
    if (authProvider.isVendorLocked) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('الحساب مغلق'),
              content: const Text('حسابك مغلق مؤقتًا، يرجى إغلاق التطبيق وإعادة فتحه بعد فتح الحساب من قبل الإدارة'),
            );
          },
        );
      }
      return;
    }

    // Try to fetch the latest vendor data from the API first
    try {
      final profileResponse = await _vendorService.getProfile();
      if (profileResponse.success && profileResponse.data != null) {
        _currentVendor = profileResponse.data!;
        // Update the auth provider with fresh data
        authProvider.updateVendor(_currentVendor!);
      } else {
        // Fallback to cached vendor if API fails
        _currentVendor = authProvider.vendor;
      }
    } catch (e) {
      // On error, fallback to cached vendor
      _currentVendor = authProvider.vendor;
    }

    // Set the controller values if we have vendor data
    if (_currentVendor != null && mounted) {
      setState(() {
        _vendorNameController.text = _currentVendor!.vendorName;
        _contactNumberController.text = _currentVendor!.contactNumber;
        _addressController.text = _currentVendor!.address;
        _descriptionController.text = _currentVendor!.description;
        _latitudeController.text = _currentVendor!.latitude?.toStringAsFixed(6) ?? '';
        _longitudeController.text = _currentVendor!.longitude?.toStringAsFixed(6) ?? '';
        _selectedNeighborhoodId = _currentVendor!.neighborhoodId?.toString();
        _selectedCategoryIds = _currentVendor!.categories?.map((cat) => cat.id).toList() ?? [];
      });
    }
  }

  /// Lets the vendor photograph the image directly instead of only picking an
  /// existing file.
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في اختيار الصورة: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if vendor is locked before attempting to save
    if (authProvider.isVendorLocked) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('الحساب مغلق'),
              content: const Text('حسابك مغلق مؤقتًا، يرجى إغلاق التطبيق وإعادة فتحه بعد فتح الحساب من قبل الإدارة'),
            );
          },
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _vendorService.updateProfile(
        vendorName: _vendorNameController.text.trim(),
        contactNumber: _contactNumberController.text.trim(),
        address: _addressController.text.trim(),
        description: _descriptionController.text.trim(),
        latitude: double.tryParse(_latitudeController.text) ??
            _currentVendor!.latitude,
        longitude: double.tryParse(_longitudeController.text) ??
            _currentVendor!.longitude,
        neighborhoodId: _selectedNeighborhoodId != null
            ? int.tryParse(_selectedNeighborhoodId!)
            : null,
        categories: _selectedCategoryIds.isNotEmpty
            ? _selectedCategoryIds.map((id) => int.parse(id)).toList()
            : null,
        image: _selectedImage,
      );

      if (response.success && response.data != null) {
        // Update the vendor in AuthProvider
        authProvider.updateVendor(response.data!);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الملف الشخصي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } else if (response.error != null && response.error!.contains('يرجى الانتظار حتى يتم فتح الحساب')) {
        // Update auth provider to indicate vendor is locked
        authProvider.setVendorLockStatus(true);
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('الحساب مغلق'),
                content: const Text('حسابك مغلق مؤقتًا، يرجى إغلاق التطبيق وإعادة فتحه بعد فتح الحساب من قبل الإدارة'),
              );
            },
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'فشل في تحديث الملف الشخصي'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.white),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildBasicInfoSection(),
              const SizedBox(height: 16),
              _buildLocationSection(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('صورة المطعم',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: _selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(60),
                        child: Image.file(
                          _selectedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : _currentVendor?.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.network(
                              _currentVendor!.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.store,
                                  size: 50,
                                  color: Colors.grey[600],
                                );
                              },
                            ),
                          )
                        : Icon(
                            Icons.store,
                            size: 50,
                            color: Colors.grey[600],
                          ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showImageSourceSheet,
              icon: const Icon(Icons.camera_alt, size: 20),
              label: const Text('تغيير الصورة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('المعلومات الأساسية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 20),
            TextFormField(
              controller: _vendorNameController,
              decoration: InputDecoration(
                labelText: 'اسم المطعم',
                prefixIcon: const Icon(Icons.store),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال اسم المطعم';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contactNumberController,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال رقم الهاتف';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'العنوان',
                prefixIcon: const Icon(Icons.location_on),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال العنوان';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'وصف المطعم',
                prefixIcon: const Icon(Icons.description),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'يرجى إدخال وصف المطعم';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
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
              prefixIcon: Icon(Icons.location_city, color: Colors.purple[700]),
            ),
            const SizedBox(height: 16),

            // Category Selection
            CategorySelector(
              selectedCategoryIds: _selectedCategoryIds,
              onChanged: (categoryIds) {
                setState(() {
                  _selectedCategoryIds = categoryIds;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى اختيار تصنيف واحد على الأقل';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معلومات الموقع',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 20),

            // Add the UpdateLocationWidget here
            UpdateLocationWidget(
              onLocationUpdated: _handleLocationUpdate,
              isLoading: _isLoading,
              currentLatitude: _latitudeController.text.isNotEmpty
                  ? double.tryParse(_latitudeController.text)
                  : null,
              currentLongitude: _longitudeController.text.isNotEmpty
                  ? double.tryParse(_longitudeController.text)
                  : null,
              showCurrentLocation: true,
              buttonText: 'الحصول على الموقع الحالي',
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latitudeController,
                    textDirection: TextDirection.ltr,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'خط العرض',
                      prefixIcon: const Icon(Icons.my_location),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (double.tryParse(value) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _longitudeController,
                    textDirection: TextDirection.ltr,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'خط الطول',
                      prefixIcon: const Icon(Icons.place),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (double.tryParse(value) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _showLocationOnMap,
                icon: const Icon(Icons.map),
                label: const Text('عرض الموقع على الخريطة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'يمكنك الحصول على إحداثيات الموقع من خرائط جوجل أو استخدام الزر أعلاه',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue[700],
                      ),
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

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
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
                  Icon(Icons.save, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'حفظ التغييرات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _handleLocationUpdate(double latitude, double longitude) {
    setState(() {
      _latitudeController.text = latitude.toStringAsFixed(6);
      _longitudeController.text = longitude.toStringAsFixed(6);
    });
  }

  Future<void> _showLocationOnMap() async {
    // Use the current coordinates from the form fields
    final lat = double.tryParse(_latitudeController.text) ?? 0.0;
    final lng = double.tryParse(_longitudeController.text) ?? 0.0;
    
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
          } else {

          }
        } catch (e) {
          lastError = e.toString();

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

  @override
  void dispose() {
    _vendorNameController.dispose();
    _contactNumberController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}
