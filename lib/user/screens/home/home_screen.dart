import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/vendor.dart';
import '../../models/category.dart';
import '../../services/user_vendor_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/skeleton_widget.dart';
import '../../widgets/common/smart_image.dart';
import '../vendors/vendor_details_screen.dart';
import '../orders/create_order_screen.dart';
import '../../widgets/home/promo_ad_carousel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final UserVendorService _vendorService = UserVendorService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<Category> _categories = [];
  String? _selectedCategoryId;

  List<Vendor> _vendors = [];
  bool _isLoadingVendors = true;
  String? _vendorsError;

  bool _isSearching = false;
  String _currentSearchQuery = '';

  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadCategories();
    _loadUserLocation();
    _loadVendors();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        setState(() {
          _isSearching = false;
          _currentSearchQuery = '';
        });
        _loadVendors();
      } else {
        setState(() {
          _isSearching = true;
          _currentSearchQuery = query;
        });
        _performSearch(query);
      }
    });
  }

  Future<void> _loadCategories() async {
    final response = await _vendorService.getCategories();
    if (!mounted) return;
    if (response.success && response.data != null) {
      setState(() => _categories = response.data!);
    }
  }

  Future<void> _loadUserLocation() async {
    final result = await _locationService.getCurrentLocation();
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _userLatitude = result.latitude;
        _userLongitude = result.longitude;
      });
      _sortVendorsByDistance();
    }
  }

  Future<void> _sortVendorsByDistance() async {
    if (_userLatitude == null || _userLongitude == null) return;
    if (_vendors.isEmpty) return;

    final vendors = List<Vendor>.from(_vendors);
    final distances = await Future.wait(
      vendors.map(
        (vendor) => _locationService.distanceBetween(
          _userLatitude!,
          _userLongitude!,
          vendor.latitude,
          vendor.longitude,
        ),
      ),
    );

    final indexed = List<int>.generate(vendors.length, (i) => i)
      ..sort((a, b) => distances[a].compareTo(distances[b]));
    final sorted = indexed.map((i) => vendors[i]).toList();

    if (!mounted) return;
    setState(() => _vendors = sorted);
  }

  Future<void> _loadVendors() async {
    setState(() {
      _isLoadingVendors = true;
      _vendorsError = null;
    });

    try {
      final response = await _vendorService.getVendors(
        page: 1,
        limit: 20,
        categoryId: _selectedCategoryId,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        setState(() {
          _vendors = response.data!;
          _isLoadingVendors = false;
        });
        _sortVendorsByDistance();
      } else {
        setState(() {
          _vendorsError = response.error ?? 'فشل في تحميل المتاجر';
          _isLoadingVendors = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vendorsError = 'حدث خطأ: ${e.toString()}';
        _isLoadingVendors = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoadingVendors = true;
      _vendorsError = null;
    });

    try {
      final response = await _vendorService.searchVendors(
        query: query,
        page: 1,
        limit: 20,
        categoryId: _selectedCategoryId,
      );

      if (!mounted) return;

      if (response.success && response.data != null) {
        setState(() {
          _vendors = response.data!;
          _isLoadingVendors = false;
        });
      } else {
        setState(() {
          _vendorsError = response.error ?? 'فشل في البحث عن المتاجر';
          _isLoadingVendors = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _vendorsError = 'حدث خطأ: ${e.toString()}';
        _isLoadingVendors = false;
      });
    }
  }

  void _onCategorySelected(String? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    if (_isSearching && _currentSearchQuery.isNotEmpty) {
      _performSearch(_currentSearchQuery);
    } else {
      _loadVendors();
    }
  }

  void _navigateToVendorDetails(Vendor vendor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VendorDetailsScreen(vendor: vendor),
      ),
    );
  }

  void _navigateToCustomOrder({bool isSendPackage = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateOrderScreen(
          isCustomOrder: !isSendPackage,
          isSendPackage: isSendPackage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadCategories();
            if (_isSearching && _currentSearchQuery.isNotEmpty) {
              await _performSearch(_currentSearchQuery);
            } else {
              await _loadVendors();
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildSearchHeader()),
              const SliverToBoxAdapter(child: PromoAdCarousel()),
              SliverToBoxAdapter(child: _buildCategoryChips()),
              SliverToBoxAdapter(child: _buildQuickPicks()),
              SliverToBoxAdapter(child: _buildCustomOrderBanner()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    _isSearching ? 'نتائج البحث' : 'الأقرب لك',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildVendorsSliver(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withOpacity(0.75),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              '🛵 اطلب اللي في بالك... تعالالي هيجبهالك! 💚',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'محتاج ايه النهاردة؟',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _searchController.clear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildCategoryChip(label: 'الكل', categoryId: null),
          const SizedBox(width: 8),
          for (final category in _categories) ...[
            _buildCategoryChip(label: category.name, categoryId: category.id),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required String? categoryId,
  }) {
    final isSelected = _selectedCategoryId == categoryId;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onCategorySelected(categoryId),
      selectedColor: AppTheme.primaryColor,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
        ),
      ),
    );
  }

  /// Picks the categories shown under "في بالك إيه دلوقتي؟".
  /// one shorter.
  Widget _buildQuickPicks() {
    if (_categories.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Text(
              'في بالك إيه دلوقتي؟',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) =>
                  _buildQuickPickItem(_categories[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPickItem(Category category) {
    return GestureDetector(
      onTap: () => _onCategorySelected(category.id),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: category.imageUrl != null
                  ? SmartImage(
                      imageSource: category.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: _quickPickFallbackIcon(),
                    )
                  : _quickPickFallbackIcon(),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickPickFallbackIcon() {
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppTheme.backgroundColor,
      child: Icon(
        Icons.category_outlined,
        color: AppTheme.primaryColor,
        size: 28,
      ),
    );
  }

  Widget _buildCustomOrderBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateToCustomOrder(),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('طلب خاص'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _navigateToCustomOrder(isSendPackage: true),
              icon: const Icon(Icons.local_shipping, size: 18),
              label: const Text('ارسال طرد'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorsSliver() {
    if (_isLoadingVendors) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.builder(
          itemCount: 3,
          itemBuilder: (context, index) => _buildVendorCardSkeleton(),
        ),
      );
    }

    if (_vendorsError != null) {
      return SliverToBoxAdapter(child: _buildErrorState());
    }

    if (_vendors.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: _vendors.length,
        itemBuilder: (context, index) => _buildVendorCard(_vendors[index]),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(_vendorsError!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSearching && _currentSearchQuery.isNotEmpty
                ? () => _performSearch(_currentSearchQuery)
                : _loadVendors,
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
        children: [
          Icon(Icons.store_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'لا توجد متاجر متاحة حالياً',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard(Vendor vendor) {
    final isOpen = vendor.isOpen.toLowerCase() == 'true';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isOpen ? () => _navigateToVendorDetails(vendor) : null,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: vendor.imageUrl != null
                    ? SmartImage(
                        imageSource: vendor.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Icon(
                          Icons.store,
                          size: 32,
                          color: Colors.grey[500],
                        ),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vendor.vendorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? AppTheme.successColor.withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isOpen ? 'مفتوح' : 'مغلق',
                            style: TextStyle(
                              color: isOpen
                                  ? AppTheme.successColor
                                  : Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (vendor.categories.isNotEmpty)
                      Text(
                        vendor.categories.map((c) => c.name).join(' • '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            vendor.address,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildVendorCardSkeleton() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SkeletonWidget(
            width: 100,
            height: 100,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonWidget(height: 16, width: 120),
                  const SizedBox(height: 8),
                  const SkeletonWidget(height: 12, width: 160),
                  const SizedBox(height: 8),
                  const SkeletonWidget(height: 12, width: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
