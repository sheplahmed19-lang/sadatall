import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/user_profile.dart';
import '../../services/user_service.dart';
import '../../services/neighborhood_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_overlay.dart';
import '../../models/auth_models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final _formKey = GlobalKey<FormState>();

  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;
  String? _selectedNeighborhoodId;
  List<Neighborhood> _allNeighborhoods = [];

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserProfile();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await _userService.getUserProfile();

      if (mounted) {
        if (response.success && response.data != null) {
          if (mounted) {
            setState(() {
              _userProfile = response.data!;
              _nameController.text = _userProfile!.userName;
              _emailController.text = _userProfile!.email;
              _phoneController.text = _userProfile!.phoneNumber;
              _selectedNeighborhoodId = _userProfile!.neighborhoodId;
            });
          }
        } else {
          if (response.error != null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(response.error!),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('401') ||
            e.toString().contains('unauthorized')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('يرجى تسجيل الدخول مجددًا'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('حدث خطأ أثناء تحميل الملف الشخصي: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }

    // Load neighborhoods after loading user profile
    await _loadNeighborhoods();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadNeighborhoods() async {
    // Import the neighborhood service locally
    final neighborhoodService = NeighborhoodService();

    try {
      final response = await neighborhoodService.getNeighborhoods();

      if (mounted && response.success && response.data != null) {
        final neighborhoods = response.data!;
        setState(() {
          _allNeighborhoods = neighborhoods;
          _selectedNeighborhoodId = _userProfile?.neighborhoodId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل الأحياء: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  String? _getNeighborhoodName(String? neighborhoodId) {
    if (neighborhoodId == null) return null;
    final neighborhood = _allNeighborhoods.firstWhere(
        (n) => n.id == neighborhoodId,
        orElse: () => Neighborhood(
            id: neighborhoodId, name: neighborhoodId, nameAr: neighborhoodId));
    return neighborhood.nameAr.isNotEmpty
        ? neighborhood.nameAr
        : neighborhood.name;
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _userService.updateUserProfile(
        userName: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        neighborhoodId: _selectedNeighborhoodId,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response.success && response.data != null) {
          setState(() {
            _userProfile = response.data!;
            _isEditing = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'تم تحديث الملف الشخصي بنجاح'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          if (response.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.error!),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحديث الملف الشخصي: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_userProfile != null)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: _isEditing ? _updateProfile : _toggleEdit,
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        message: 'جاري تحميل البيانات...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_userProfile == null && !_isLoading) ...[
                  const Center(
                    child: Text('لا يمكن تحميل بيانات الملف الشخصي'),
                  ),
                ] else if (!_isLoading) ...[
                  // Profile Info Card
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person,
                            size: 80,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _userProfile?.userName ?? '--',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userProfile?.email ?? '--',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form fields
                  CustomTextField(
                    label: 'الاسم',
                    controller: _nameController,
                    prefixIcon: Icons.person,
                    enabled: _isEditing,
                    validator: (value) {
                      if (_isEditing &&
                          (value == null || value.trim().isEmpty)) {
                        return 'يرجى إدخال الاسم';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'البريد الإلكتروني',
                    controller: _emailController,
                    prefixIcon: Icons.email,
                    enabled: false,
                    keyboardType: TextInputType.emailAddress,
                    validator: null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  CustomTextField(
                    label: 'رقم الهاتف',
                    controller: _phoneController,
                    prefixIcon: Icons.phone,
                    enabled: _isEditing,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(15),
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: _isEditing
                        ? (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'يرجى إدخال رقم الهاتف';
                            }
                            if (value.length < 10) {
                              return 'رقم الهاتف يجب أن يكون 10 أرقام على الأقل';
                            }
                            return null;
                          }
                        : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Neighborhood Selection
                  if (_isEditing)
                    _allNeighborhoods.isNotEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                  12, 0, 4, 0),
                              child: DropdownButtonFormField<String>(
                                value: _selectedNeighborhoodId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'الحي *',
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.location_city,
                                      color: Colors.purple),
                                  prefixIconConstraints:
                                      BoxConstraints(minWidth: 48),
                                ),
                                hint: const Text('اختر المنطقة'),
                                items: _allNeighborhoods.map((neighborhood) {
                                  return DropdownMenuItem<String>(
                                    value: neighborhood.id,
                                    child: Text(
                                      neighborhood.nameAr.isNotEmpty
                                          ? neighborhood.nameAr
                                          : neighborhood.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedNeighborhoodId = value;
                                  });
                                },
                                validator: _isEditing
                                    ? (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'يرجى اختيار الحي';
                                        }
                                        return null;
                                      }
                                    : null,
                              ),
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.location_city,
                                    color: Colors.purple[700]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'جاري تحميل الأحياء...',
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_city, color: Colors.purple[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _getNeighborhoodName(
                                      _userProfile?.neighborhoodId) ??
                                  'غير محدد',
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  if (_isEditing)
                    CustomButton(
                      text: 'تحديث الملف',
                      onPressed: _updateProfile,
                      height: 52,
                      icon: Icons.save,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
