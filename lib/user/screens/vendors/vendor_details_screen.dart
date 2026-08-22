import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/vendor.dart';
import '../../models/menu_item.dart';
import '../../models/product_item.dart';
import '../../services/user_vendor_service.dart';
import '../../services/cart_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/common/skeleton_widget.dart';
import '../../widgets/common/smart_image.dart';
import '../../widgets/common/clickable_phone_field.dart';
import '../orders/create_order_screen.dart';
import '../items/product_item_details_screen.dart';

class VendorDetailsScreen extends StatefulWidget {
  final Vendor vendor;

  const VendorDetailsScreen({super.key, required this.vendor});

  @override
  State<VendorDetailsScreen> createState() => _VendorDetailsScreenState();
}

class _VendorDetailsScreenState extends State<VendorDetailsScreen> {
  final UserVendorService _vendorService = UserVendorService();
  final CartService _cartService = CartService();

  int _selectedTabIndex = 0; // 0 = menu, 1 = products

  List<MenuItem> _menuItems = [];
  List<ProductItem> _productItems = [];
  bool _isLoading = true;
  bool _isLoadingProducts = true;
  String? _error;
  String? _productError;
  bool _isLoadingMore = false;
  bool _isLoadingMoreProducts = false;
  int _currentPage = 1;
  int _currentProductPage = 1;
  bool _hasMoreData = true;
  bool _hasMoreProducts = true;
  String _searchQuery = '';

  // Single scroll controller for the whole page - there is only ever one
  // scrollable now, so the outer page and the visible tab's items scroll
  // together instead of fighting each other as two separate scrollables.
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<ProductItem> get _filteredProductItems {
    if (_searchQuery.trim().isEmpty) return _productItems;
    final query = _searchQuery.trim().toLowerCase();
    return _productItems
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _checkCartVendor();
    _loadMenuItems();
    _loadProductItems();
    _scrollController.addListener(_onScroll);
    _cartService.addListener(_onCartChanged);
  }

  bool get _shouldShowTabs => !_isLoading && _menuItems.isNotEmpty;

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    setState(() {
      // Rebuild UI when cart changes
    });
  }

  Future<void> _checkCartVendor() async {
    // Check if cart has items from a different vendor
    if (_cartService.isNotEmpty &&
        _cartService.needsVendorSwitch(widget.vendor.id)) {
      // Delay to ensure context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final confirmed = await _showVendorSwitchDialog();
        if (confirmed) {
          _cartService.clearCart();
        } else {
          // User declined, navigate back
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      });
    }
  }

  // Single listener on the one page-wide scroll controller: only trigger
  // load-more for whichever tab is currently visible.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 200) {
      return;
    }

    if (_selectedTabIndex == 0) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreMenuItems();
      }
    } else {
      if (!_isLoadingMoreProducts && _hasMoreProducts) {
        _loadMoreProductItems();
      }
    }
  }

  Future<void> _loadMenuItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _vendorService.getVendorMenus(
        widget.vendor.id,
        page: 1,
        limit: 20,
      );

      if (response.success && response.data != null) {
        setState(() {
          _menuItems = response.data!;
          _isLoading = false;
          _currentPage = 1;
          _hasMoreData = response.data!.length >= 20;
        });
      } else {
        setState(() {
          _error = response.error ?? 'فشل في تحميل قائمة الطعام';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreMenuItems() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _vendorService.getVendorMenus(
        widget.vendor.id,
        page: _currentPage + 1,
        limit: 20,
      );

      if (response.success && response.data != null) {
        setState(() {
          _menuItems.addAll(response.data!);
          _currentPage++;
          _hasMoreData = response.data!.length >= 20;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadProductItems() async {
    setState(() {
      _isLoadingProducts = true;
      _productError = null;
    });

    try {
      final response = await _vendorService.getVendorItems(
        widget.vendor.id,
        page: 1,
        limit: 20,
      );

      if (response.success && response.data != null) {
        setState(() {
          _productItems = response.data!;
          _isLoadingProducts = false;
          _currentProductPage = 1;
          _hasMoreProducts = response.data!.length >= 20;
        });
      } else {
        setState(() {
          _productError = response.error ?? 'فشل في تحميل المنتجات';
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      setState(() {
        _productError = 'حدث خطأ: ${e.toString()}';
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadMoreProductItems() async {
    if (_isLoadingMoreProducts || !_hasMoreProducts) return;

    setState(() {
      _isLoadingMoreProducts = true;
    });

    try {
      final response = await _vendorService.getVendorItems(
        widget.vendor.id,
        page: _currentProductPage + 1,
        limit: 20,
      );

      if (response.success && response.data != null) {
        setState(() {
          _productItems.addAll(response.data!);
          _currentProductPage++;
          _hasMoreProducts = response.data!.length >= 20;
          _isLoadingMoreProducts = false;
        });
      } else {
        setState(() {
          _isLoadingMoreProducts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMoreProducts = false;
      });
    }
  }

  void _navigateToCheckout() async {
    final loggedIn = await AuthGate.ensureLoggedIn(
      context,
      actionLabel: 'لإتمام الطلب',
    );
    if (!loggedIn || !mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateOrderScreen(
          vendor: widget.vendor,
          isCustomOrder: false,
          isCheckout: true,
        ),
      ),
    );

    if (result == true) {
      // Order was created successfully
      _cartService.clearCart();
    }
  }

  void _navigateToTextOrder() async {
    final loggedIn = await AuthGate.ensureLoggedIn(
      context,
      actionLabel: 'لإرسال طلبك',
    );
    if (!loggedIn || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateOrderScreen(
          vendor: widget.vendor,
          isCustomOrder: false,
          isCheckout: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar with Vendor Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.vendor.vendorName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  widget.vendor.imageUrl != null
                      ? SmartImage(
                          imageSource: widget.vendor.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.store,
                            size: 80,
                            color: Colors.grey[500],
                          ),
                        ),
                  // Gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black26,
                          Colors.black54,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Vendor Information
          SliverToBoxAdapter(child: _buildVendorInfo()),

          // Search bar for products
          if (!_isLoadingProducts && _productItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن صنف...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
            ),

          // Tab Bar (only show if menu has items)
          if (_shouldShowTabs)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTabButton('قائمة الطعام', 0),
                    _buildTabButton('المنتجات', 1),
                  ],
                ),
              ),
            ),

          // Items for whichever tab is selected, rendered as slivers directly
          // in this single scroll view (no nested scrollables).
          if (!_shouldShowTabs || _selectedTabIndex == 1)
            ..._buildProductItemsSlivers()
          else
            ..._buildMenuItemsSlivers(),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuItemsSlivers() {
    if (_isLoading) {
      return [SliverToBoxAdapter(child: _buildLoadingState())];
    }

    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: _buildErrorStateWithCallback(_error!, _loadMenuItems),
        ),
      ];
    }

    if (_menuItems.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _buildEmptyStateWithMessage('لا توجد عناصر في القائمة'),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= _menuItems.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildMenuItemCard(_menuItems[index]);
          }, childCount: _menuItems.length + (_isLoadingMore ? 1 : 0)),
        ),
      ),
    ];
  }

  List<Widget> _buildProductItemsSlivers() {
    if (_isLoadingProducts) {
      return [SliverToBoxAdapter(child: _buildLoadingState())];
    }

    if (_productError != null) {
      return [
        SliverToBoxAdapter(
          child: _buildErrorStateWithCallback(
            _productError!,
            _loadProductItems,
          ),
        ),
      ];
    }

    if (_productItems.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _buildEmptyStateWithMessage('لا توجد منتجات متاحة'),
        ),
      ];
    }

    final filteredItems = _filteredProductItems;

    if (filteredItems.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _buildEmptyStateWithMessage('لا توجد نتائج مطابقة للبحث'),
        ),
      ];
    }

    final showLoader = _isLoadingMoreProducts && _searchQuery.trim().isEmpty;

    return [
      SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= filteredItems.length) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildProductItemCard(filteredItems[index]);
          }, childCount: filteredItems.length + (showLoader ? 1 : 0)),
        ),
      ),
    ];
  }

  Widget _buildVendorInfo() {
    final theme = Theme.of(context);
    final isOpen = widget.vendor.isOpen.toLowerCase() == 'true';

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.vendor.vendorName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor, // Blue color for vendor name
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOpen
                      ? AppTheme.successColor.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOpen ? AppTheme.successColor : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOpen ? 'مفتوح' : 'مغلق',
                      style: TextStyle(
                        color: isOpen ? AppTheme.successColor : Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.vendor.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.vendor.description,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 16),

          // Address
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.vendor.address,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),

           

          const SizedBox(height: 16),

          // Order Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: isOpen ? _navigateToCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.shopping_cart_checkout, size: 20),
              label: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isOpen ? 'الذهاب للدفع' : 'المتجر مغلق حالياً',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isOpen && _cartService.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_cartService.getTotalItemsPrice().toStringAsFixed(0)} جنيه',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_cartService.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _confirmClearCart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: const Text(
                  'إفراغ السلة',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],

          if (isOpen && _cartService.isEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _navigateToTextOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.edit_note, size: 20),
                label: const Text(
                  'اطلب بكتابة طلبك',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    if (_isLoading) {
      return SliverToBoxAdapter(child: _buildLoadingState());
    }

    if (_error != null) {
      return SliverToBoxAdapter(child: _buildErrorState());
    }

    if (_menuItems.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= _menuItems.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final menuItem = _menuItems[index];
          return _buildMenuItemCard(menuItem);
        }, childCount: _menuItems.length + (_isLoadingMore ? 1 : 0)),
      ),
    );
  }

  void _showMenuItemDetails(MenuItem menuItem) {
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
                  child: menuItem.photoUrl != null
                      ? SmartImage(
                          imageSource: menuItem.photoUrl!,
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
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
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

  Widget _buildMenuItemCard(MenuItem menuItem) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showMenuItemDetails(menuItem),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Menu Item Image
              Expanded(
                flex: 3, // Adjust the flex to give more space to image
                child: Hero(
                  tag: 'menu-item-${menuItem.id}',
                  child: Container(
                    decoration: BoxDecoration(color: Colors.grey[200]),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: menuItem.photoUrl != null
                              ? SmartImage(
                                  imageSource: menuItem.photoUrl!,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: Icon(
                                    Icons.restaurant_menu,
                                    size: 32,
                                    color: Colors.grey[500],
                                  ),
                                ),
                        ),
                        // Zoom indicator overlay
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Menu Item Info
              Expanded(
                flex: 2, // Adjust the flex to give appropriate space to info
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:
                        MainAxisAlignment.center, // Center content vertically
                    children: [
                      Text(
                        'عنصر القائمة ${menuItem.id}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 12,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            // Wrap text in Expanded to prevent overflow
                            child: Text(
                              'اضغط للعرض بالحجم الكامل',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                              maxLines: 1, // Limit to 1 line
                              overflow: TextOverflow
                                  .ellipsis, // Add ellipsis if overflow
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 8,
          mainAxisSpacing: 16,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildMenuItemCardSkeleton(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadMenuItems,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'لا توجد عناصر في القائمة',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemCardSkeleton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SkeletonWidget(
              width: double.infinity,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidget(height: 16, width: double.infinity),
                SizedBox(height: 4),
                SkeletonWidget(height: 14, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorStateWithCallback(
    String errorMessage,
    VoidCallback onRetry,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateWithMessage(String message) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItemCard(ProductItem productItem) {
    final theme = Theme.of(context);
    final quantity = _cartService.getItemQuantity(productItem.id);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProductItemDetailsScreen(
                productItem: productItem,
                isEditable: false,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Item Image
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: productItem.imageUrl != null
                            ? SmartImage(
                                imageSource: productItem.imageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.grey[300],
                                child: Icon(
                                  Icons.shopping_bag,
                                  size: 32,
                                  color: Colors.grey[500],
                                ),
                              ),
                      ),
                      // Availability badge
                      if (!productItem.isAvailable)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'غير متاح',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Product Info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Product name
                    Text(
                      productItem.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price (or starting-from price when sizes exist, since
                    // each size can have a different price)
                    Text(
                      productItem.sizes.isEmpty
                          ? '${productItem.price.toStringAsFixed(0)} جنيه'
                          : 'يبدأ من ${_minSizePrice(productItem).toStringAsFixed(0)} جنيه',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Product description
                    if (productItem.description.isNotEmpty)
                      Text(
                        productItem.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Counter buttons (single price) or a size-picker button
              // (multiple sizes — each has its own price/cart line)
              if (productItem.isAvailable)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: productItem.sizes.isEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Minus button
                            InkWell(
                              onTap: quantity > 0
                                  ? () => _updateCartItem(productItem, -1)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: quantity > 0
                                      ? AppTheme.primaryColor
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: quantity > 0
                                      ? Colors.white
                                      : Colors.grey[500],
                                  size: 18,
                                ),
                              ),
                            ),

                            // Quantity display
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: quantity > 0
                                    ? AppTheme.primaryColor.withOpacity(0.1)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                quantity.toString(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: quantity > 0
                                      ? AppTheme.primaryColor
                                      : Colors.grey[600],
                                ),
                              ),
                            ),

                            // Plus button
                            InkWell(
                              onTap: () => _updateCartItem(productItem, 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showSizePicker(productItem),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.add_shopping_cart, size: 16),
                            label: Text(
                              _totalQuantityForProduct(productItem) > 0
                                  ? 'في السلة (${_totalQuantityForProduct(productItem)}) · اختيار الحجم'
                                  : 'اختيار الحجم',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _minSizePrice(ProductItem product) {
    final available = product.sizes.where((s) => s.isAvailable).toList();
    final pool = available.isNotEmpty ? available : product.sizes;
    return pool.map((s) => s.effectivePrice).reduce((a, b) => a < b ? a : b);
  }

  int _totalQuantityForProduct(ProductItem product) {
    return _cartService.items
        .where((item) => item.productId == product.id)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  Future<void> _updateCartItem(ProductItem product, int delta, {ItemSizeOption? size}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    // Check if we need to switch vendors
    if (delta > 0 && _cartService.needsVendorSwitch(widget.vendor.id)) {
      final confirmed = await _showVendorSwitchDialog();
      if (!confirmed) {
        return;
      }
      _cartService.clearCart();
    }

    if (delta > 0) {
      _cartService.addItem(product, widget.vendor.id, widget.vendor.vendorName, size: size);
    } else {
      _cartService.removeItem(product.id, sizeId: size?.id);
    }
  }

  Future<void> _showSizePicker(ProductItem product) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(sheetContext)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  for (final size in product.sizes.where((s) => s.isAvailable))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${size.name} — ${size.effectivePrice.toStringAsFixed(0)} جنيه',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _cartService.getItemQuantity(product.id, sizeId: size.id) > 0
                                ? () async {
                                    await _updateCartItem(product, -1, size: size);
                                    setSheetState(() {});
                                  }
                                : null,
                          ),
                          Text(
                            '${_cartService.getItemQuantity(product.id, sizeId: size.id)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: AppTheme.primaryColor),
                            onPressed: () async {
                              await _updateCartItem(product, 1, size: size);
                              setSheetState(() {});
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                      child: const Text('تم'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  /// Removes every item from the cart after confirmation.
  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('إفراغ السلة'),
          content: const Text('هل تريد حذف كل العناصر من السلة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('حذف الكل'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    _cartService.clearCart();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إفراغ السلة')),
    );
  }

  Future<bool> _showVendorSwitchDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تبديل المتجر'),
          content: Text(
            'لديك عناصر من "${_cartService.vendorName}" في السلة. هل تريد حذفها والبدء بعناصر من "${widget.vendor.vendorName}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
