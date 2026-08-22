import 'package:flutter/material.dart';
import '../../models/order.dart';
import '../../services/user_order_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_gate.dart';
import '../../widgets/orders/order_card.dart';
import 'create_order_screen.dart';
import 'order_details_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  final UserOrderService _orderService = UserOrderService();
  late TabController _tabController;
  
  // Store orders for each tab separately with loading state
  Map<String, List<Order>> _ordersByStatus = {};
  Map<String, bool> _isLoadingByTab = {};
  Map<String, String?> _errorByTab = {};
  bool _isLoading = false; // Overall loading state (for initial screen)
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // Updated to 6 tabs

    // Initialize loading states for all tabs
    _isLoadingByTab = {
      'all': false,
      OrderStatus.pending: false,
      OrderStatus.counterOfferAccepted: false,
      OrderStatus.acceptedByCaptain: false,
      OrderStatus.delivered: false,
      OrderStatus.cancelled: false,
    };

    _ordersByStatus = {
      'all': [],
      OrderStatus.pending: [],
      OrderStatus.counterOfferAccepted: [],
      OrderStatus.acceptedByCaptain: [],
      OrderStatus.delivered: [],
      OrderStatus.cancelled: [],
    };

    _errorByTab = {
      'all': null,
      OrderStatus.pending: null,
      OrderStatus.counterOfferAccepted: null,
      OrderStatus.acceptedByCaptain: null,
      OrderStatus.delivered: null,
      OrderStatus.cancelled: null,
    };
    
    // Set up listener to load data when tab is selected
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadOrdersForActiveTab();
      }
    });
    
    // Load data for the initially active tab (index 0 - 'all')
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrdersForActiveTab();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadOrdersForActiveTab() {
    if (_tabController.indexIsChanging) return;

    int activeIndex = _tabController.index;
    String status;

    switch (activeIndex) {
      case 0:
        status = 'all';
        break;
      case 1:
        status = OrderStatus.pending;
        break;
      case 2:
        status = OrderStatus.counterOfferAccepted;
        break;
      case 3:
        status = OrderStatus.acceptedByCaptain;
        break;
      case 4:
        status = OrderStatus.delivered;
        break;
      case 5:
        status = OrderStatus.cancelled;
        break;
      default:
        status = 'all';
    }

    // Always fetch fresh data from DB when tab is clicked, regardless of current orders
    _loadOrdersByStatus(status);
  }

  Future<void> _loadOrdersByStatus(String status) async {
    // Always fetch fresh data from DB when tab is clicked, regardless of current state
    // Skip if already loading to prevent duplicate requests
    if (_isLoadingByTab[status] == true) {
      // Wait briefly before trying again, to allow UI to potentially update
      await Future.delayed(const Duration(milliseconds: 100));
      // Try again after delay to ensure fresh fetch
      if (_isLoadingByTab[status] == true) return;
    }
    
    setState(() {
      _isLoadingByTab[status] = true;
      _errorByTab[status] = null;
    });

    try {
      // For 'all' tab, we'll fetch all orders without status filter
      // For specific status, we'll fetch only orders with that status from the API
      List<Order> orders;
      if (status == 'all') {
        final response = await _orderService.getUserOrders();
        if (response.success && response.data != null) {
          orders = response.data!;
        } else {
          throw Exception(response.error ?? 'فشل في تحميل الطلبات');
        }
      } else {
        // For specific status, fetch only orders with that status directly from API
        final response = await _orderService.getUserOrders(status: status);
        if (response.success && response.data != null) {
          orders = response.data!;
        } else {
          throw Exception(response.error ?? 'فشل في تحميل الطلبات');
        }
      }
      
      setState(() {
        _ordersByStatus[status] = orders;
        _isLoadingByTab[status] = false;
      });
    } catch (e) {
      setState(() {
        _ordersByStatus[status] = [];
        _errorByTab[status] = 'حدث خطأ أثناء تحميل الطلبات: ${e.toString()}';
        _isLoadingByTab[status] = false;
      });
    }
  }

  /// Opens the custom-order form, asking a guest to sign in first.
  Future<void> _navigateToCustomOrder() async {
    final loggedIn = await AuthGate.ensureLoggedIn(
      context,
      actionLabel: 'لإنشاء طلب خاص',
    );
    if (!loggedIn || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateOrderScreen(isCustomOrder: true),
      ),
    );

    if (mounted) {
      await _refreshOrders();
    }
  }

  Future<void> _refreshOrders() async {
    // Clear cached data for all tabs to force reload
    setState(() {
      _ordersByStatus = {
        'all': [],
        OrderStatus.pending: [],
        OrderStatus.counterOfferAccepted: [],
        OrderStatus.acceptedByCaptain: [],
        OrderStatus.delivered: [],
        OrderStatus.cancelled: [],
      };

      _errorByTab = {
        'all': null,
        OrderStatus.pending: null,
        OrderStatus.counterOfferAccepted: null,
        OrderStatus.acceptedByCaptain: null,
        OrderStatus.delivered: null,
        OrderStatus.cancelled: null,
      };
    });

    // Reload data for current tab
    _loadOrdersForActiveTab();
  }

  // Build a tab with tap handling to allow refresh when clicking active tab
  Widget _buildTab(String text, IconData icon, int tabIndex) {
    return Tab(
      height: 48, // Reduce tab height to save space
      child: GestureDetector(
        onTap: () {
          // If this tab is already selected, refresh its data
          if (_tabController.index == tabIndex) {
            _loadOrdersForActiveTab();
          } else {
            // Otherwise switch to this tab (which will trigger data loading via listener)
            _tabController.animateTo(tabIndex);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18), // Reduce icon size to save space
            const SizedBox(height: 2), // Reduce height between icon and text
            Text(text, style: const TextStyle(fontSize: 11)), // Reduce font size
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('طلباتي'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true, // Make tabs scrollable since we have many
          indicatorWeight: 2.0, // Reduce indicator weight to help with overflow
          indicatorSize: TabBarIndicatorSize.label, // Make indicator fit the label size
          tabs: [
            // Adding tap detection to each tab to allow refresh when clicking active tab
            _buildTab('الكل', Icons.list_alt, 0),
            _buildTab(OrderStatus.getStatusDisplayName(OrderStatus.pending), Icons.access_time, 1),
            _buildTab(OrderStatus.getStatusDisplayName(OrderStatus.counterOfferAccepted), Icons.check, 2),
            _buildTab(OrderStatus.getStatusDisplayName(OrderStatus.acceptedByCaptain), Icons.local_shipping, 3),
            _buildTab(OrderStatus.getStatusDisplayName(OrderStatus.delivered), Icons.check_circle, 4),
            _buildTab(OrderStatus.getStatusDisplayName(OrderStatus.cancelled), Icons.cancel, 5),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersListForTab('all', 'لا توجد طلبات'),
          _buildOrdersListForTab(OrderStatus.pending, 'لا توجد طلبات في الانتظار'),
          _buildOrdersListForTab(OrderStatus.counterOfferAccepted, 'لا توجد طلبات مع عروض مقابل مقبولة'),
          _buildOrdersListForTab(OrderStatus.acceptedByCaptain, 'لا توجد طلبات مقبولة من الكابتن'),
          _buildOrdersListForTab(OrderStatus.delivered, 'لا توجد طلبات مكتملة'),
          _buildOrdersListForTab(OrderStatus.cancelled, 'لا توجد طلبات ملغية'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_create_order_fab',
        onPressed: _navigateToCustomOrder,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Icons.add),
        label: const Text('طلب جديد'),
      ),
    );
  }


  Widget _buildOrdersListForTab(String status, String emptyMessage) {
    final isLoading = _isLoadingByTab[status] ?? false;
    final error = _errorByTab[status];
    final orders = _ordersByStatus[status] ?? [];

    if (isLoading && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadOrdersByStatus(status),
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اطلب الآن واستمتع بخدماتنا',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _navigateToCustomOrder,
              icon: const Icon(Icons.add),
              label: const Text('إنشاء طلب جديد'),
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

    // Use a separate refresh indicator for each tab
    return RefreshIndicator(
      onRefresh: () => _loadOrdersByStatus(status),
      child: ListView.builder(
        padding: const EdgeInsets.all(12), // Reduced padding to save space
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OrderCard(
              order: order,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(order: order),
                  ),
                ).then((result) {
                  if (result == true) {
                    _refreshOrders(); // Refresh the current tab data
                  }
                });
              },
              onAction: (action) {
                // Handle quick actions from order card
                if (action == 'view') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(order: order),
                    ),
                  ).then((result) {
                    if (result == true) {
                      _refreshOrders(); // Refresh the current tab data
                    }
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }
}