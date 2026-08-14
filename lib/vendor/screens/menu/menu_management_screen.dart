import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/menu_service.dart';
import '../../models/menu_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/smart_image.dart';

import '../../providers/auth_provider.dart';
import 'add_edit_menu_screen.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final MenuService _menuService = MenuService();
  final TextEditingController _searchController = TextEditingController();

  final List<MenuItem> _allMenuItems = [];
  List<MenuItem> _filteredMenuItems = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _hasMoreItems = true;

  @override
  void initState() {
    super.initState();
    _checkVendorLockAndLoadMenuItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _checkVendorLockAndLoadMenuItems() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isVendorLocked) {
        _showVendorLockedDialog();
      } else {
        _loadMenuItems();
      }
    });
  }

  Future<void> _loadMenuItems({bool isRefresh = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before making API call
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _allMenuItems.clear();
        _filteredMenuItems.clear();
        _hasMoreItems = true;
        _isLoading = true;
      });
    }

    if (!_hasMoreItems) return;

    setState(() {
      if (isRefresh || _currentPage == 1) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final response = await _menuService.getMenus(
        page: _currentPage,
        limit: _itemsPerPage,
      );

      if (response.success && response.data != null) {
        final newItems = response.data!;

        if (newItems.isEmpty) {
          _hasMoreItems = false;
        } else {
          _allMenuItems.addAll(newItems);
          _filterMenuItems();
          _currentPage++;
        }
      } else if (response.error != null && response.error!.contains('يرجى الانتظار حتى يتم فتح الحساب')) {
        // Update auth provider to indicate vendor is locked
        authProvider.setVendorLockStatus(true);
        if (mounted) {
          _showVendorLockedDialog();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'فشل في تحميل القوائم'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء تحميل القوائم: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _filterMenuItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMenuItems = List.from(_allMenuItems);
      } else {
        _filteredMenuItems = _allMenuItems.where((item) {
          return item.id.toLowerCase().contains(query) ||
              item.vendorId.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before attempting to delete
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    final confirmed = await _showDeleteConfirmation(item);
    if (!confirmed) return;

    try {
      final response = await _menuService.deleteMenu(item.id);
      if (response.success) {
        setState(() {
          _allMenuItems.removeWhere((menuItem) => menuItem.id == item.id);
          _filterMenuItems();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message ?? 'تم حذف العنصر بنجاح'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      } else if (response.error != null && response.error!.contains('يرجى الانتظار حتى يتم فتح الحساب')) {
        // Update auth provider to indicate vendor is locked
        authProvider.setVendorLockStatus(true);
        if (mounted) {
          _showVendorLockedDialog();
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.error ?? 'فشل في حذف العنصر'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء حذف العنصر: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVendorLockedDialog() {
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
  }

  Future<bool> _showDeleteConfirmation(MenuItem item) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد الحذف'),
            content:
                Text('هل أنت متأكد من حذف هذا العنصر؟\n\nالمعرف: ${item.id}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _navigateToAddEditScreen() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Check if vendor is locked before navigating to add screen
    if (authProvider.isVendorLocked) {
      _showVendorLockedDialog();
      return;
    }

    final result = await Navigator.of(context).push<MenuItem>(
      MaterialPageRoute(
        builder: (context) => AddEditMenuScreen(), // Only allow adding new items
      ),
    );

    if (result != null) {
      _loadMenuItems(isRefresh: true);
    }
  }

  void _showMenuItemDetails(MenuItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: Stack(
              children: [
                Center(
                  child: item.photoUrl != null
                      ? SmartImage(
                          imageSource: item.photoUrl,
                          fit: BoxFit.contain,
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: Icon(
                            Icons.restaurant_menu,
                            size: 100,
                            color: Colors.grey[300],
                          ),
                        ),
                ),
                Positioned(
                  top: 50,
                  right: 20,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading && _allMenuItems.isEmpty
                ? Center(
                    child: LoadingAnimationWidget.threeArchedCircle(
                      color: AppTheme.primaryColor,
                      size: 50.0,
                    ),
                  )
                : _buildMenuList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditScreen(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إدارة القوائم',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => _filterMenuItems(),
            decoration: InputDecoration(
              hintText: 'البحث في القوائم...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    if (_filteredMenuItems.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadMenuItems(isRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredMenuItems.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredMenuItems.length) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LoadingAnimationWidget.threeArchedCircle(
                  color: AppTheme.primaryColor,
                  size: 30.0,
                ),
              ),
            );
          }

          final item = _filteredMenuItems[index];

          // Load more items when reaching the end
          if (index == _filteredMenuItems.length - 1 &&
              _hasMoreItems &&
              !_isLoadingMore) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadMenuItems();
            });
          }

          return _buildMenuItemCard(item);
        },
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItem item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Show the menu item in full screen view when tapped
          _showMenuItemDetails(item);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  // Clickable image for full-screen view
                  GestureDetector(
                    onTap: () => _showMenuItemDetails(item),
                    child: Hero(
                      tag: 'menu_image_${item.photoUrl}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[200],
                          child: item.photoUrl != null
                              ? SmartImage(
                                  imageSource: item.photoUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(
                                    Icons.restaurant_menu,
                                    color: Colors.grey,
                                    size: 30,
                                  ),
                                )
                              : const Icon(
                                  Icons.restaurant_menu,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المعرف: ${item.id}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (item.photoUrl != null)
                          Text(
                            'اضغط على الصورة للعرض بملء الشاشة',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteMenuItem(item);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('حذف'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد قوائم',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ابدأ بإضافة عنصر جديد لقائمة الطعام',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddEditScreen(),
            icon: const Icon(Icons.add),
            label: const Text('إضافة عنصر جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }


}
